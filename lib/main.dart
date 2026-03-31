import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MetaViagemApp());
}

final ValueNotifier<ThemeMode> themeModeNotifier = ValueNotifier(ThemeMode.light);

class MetaViagemApp extends StatelessWidget {
  const MetaViagemApp({super.key});
  @override
  Widget build(BuildContext context) => ValueListenableBuilder<ThemeMode>(
    valueListenable: themeModeNotifier,
    builder: (_, mode, __) => MaterialApp(
      title: 'Meta Viagem',
      debugShowCheckedModeBanner: false,
      themeMode: mode,
      theme: ThemeData(colorSchemeSeed: const Color(0xFF1D9E75), useMaterial3: true, brightness: Brightness.light),
      darkTheme: ThemeData(colorSchemeSeed: const Color(0xFF1D9E75), useMaterial3: true, brightness: Brightness.dark),
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      supportedLocales: const [Locale('pt', 'BR'), Locale('en')],
      home: const RootPage(),
    ),
  );
}

// ─── ROOT ─────────────────────────────────────────────────────────────────────

class RootPage extends StatefulWidget {
  const RootPage({super.key});
  @override
  State<RootPage> createState() => _RootPageState();
}

class _RootPageState extends State<RootPage> {
  int _tab = 0;
  late PageController _pageCtrl;
  double _atual = 0, _meta = 500, _abastecimento = 0;
  List<Map<String, dynamic>> _viagens = [];
  List<Map<String, dynamic>> _dias = [];

  @override
  void initState() {
    super.initState();
    _pageCtrl = PageController(initialPage: 0);
    _load();
  }

  @override
  void dispose() { _pageCtrl.dispose(); super.dispose(); }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    setState(() {
      _atual = p.getDouble('atual') ?? 0;
      _meta = p.getDouble('meta') ?? 500;
      _abastecimento = p.getDouble('abastecimento') ?? 0;
      final rv = p.getString('viagens'); if (rv != null) _viagens = List<Map<String, dynamic>>.from(jsonDecode(rv));
      final rd = p.getString('dias'); if (rd != null) _dias = List<Map<String, dynamic>>.from(jsonDecode(rd));
    });
  }

  Future<void> _save() async {
    final p = await SharedPreferences.getInstance();
    await p.setDouble('atual', _atual);
    await p.setDouble('meta', _meta);
    await p.setDouble('abastecimento', _abastecimento);
    await p.setString('viagens', jsonEncode(_viagens));
    await p.setString('dias', jsonEncode(_dias));
  }

  void _onHojeChanged(double atual, double meta, double abast, List<Map<String, dynamic>> viagens) {
    setState(() { _atual = atual; _meta = meta; _abastecimento = abast; _viagens = viagens; });
    _save();
  }

  void _onEncerrarDia(Map<String, dynamic> dia) {
    setState(() { _dias.insert(0, dia); _atual = 0; _viagens = []; _abastecimento = 0; });
    _save();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tabs = ['Hoje', 'Diário', 'Resumo'];
    return Scaffold(
      appBar: AppBar(
        scrolledUnderElevation: 0,
        title: const Text('Meta Viagem', style: TextStyle(fontWeight: FontWeight.w500)),
        actions: [
          ValueListenableBuilder<ThemeMode>(
            valueListenable: themeModeNotifier,
            builder: (_, mode, __) => IconButton(
              icon: Icon(mode == ThemeMode.dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
              onPressed: () => themeModeNotifier.value = mode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark,
            ),
          ),
        ],
      ),
      body: Column(children: [
        Padding(padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE8E8E2),
              borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.all(3),
            child: Row(children: List.generate(3, (i) => Expanded(
              child: GestureDetector(
                onTap: () {
                  setState(() => _tab = i);
                  _pageCtrl.animateToPage(i, duration: const Duration(milliseconds: 250), curve: Curves.easeInOut);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: _tab == i ? (isDark ? const Color(0xFF3A3A3A) : Colors.white) : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(tabs[i], textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500,
                          color: _tab == i
                            ? Theme.of(context).colorScheme.onSurface
                            : Theme.of(context).colorScheme.onSurface.withOpacity(0.45))),
                ),
              ),
            ))),
          )),
        const SizedBox(height: 12),
        Expanded(child: PageView(
          controller: _pageCtrl,
          onPageChanged: (i) => setState(() => _tab = i),
          children: [
            HojeTab(atual: _atual, meta: _meta, abastecimento: _abastecimento, viagens: _viagens,
                onChanged: _onHojeChanged, onEncerrarDia: _onEncerrarDia),
            DiarioTab(dias: _dias, onDeleteDia: (i) { setState(() => _dias.removeAt(i)); _save(); }),
            ResumoTab(dias: _dias),
          ],
        )),
      ]),
    );
  }
}

// ─── ABA HOJE ─────────────────────────────────────────────────────────────────

class HojeTab extends StatefulWidget {
  final double atual, meta, abastecimento;
  final List<Map<String, dynamic>> viagens;
  final Function(double, double, double, List<Map<String, dynamic>>) onChanged;
  final Function(Map<String, dynamic>) onEncerrarDia;
  const HojeTab({super.key, required this.atual, required this.meta, required this.abastecimento,
    required this.viagens, required this.onChanged, required this.onEncerrarDia});
  @override State<HojeTab> createState() => _HojeTabState();
}

class _HojeTabState extends State<HojeTab> {
  late double _atual, _meta, _abast;
  late List<Map<String, dynamic>> _viagens;
  bool _modoTotal = false;
  bool _ehPromocao = false;
  final _corridaCtrl = TextEditingController();
  final _metaCtrl = TextEditingController();
  final _totalCtrl = TextEditingController();
  final _nViaCtrl = TextEditingController();
  final _metaTotalCtrl = TextEditingController();
  final _kmCtrl = TextEditingController();
  final _horasCtrl = TextEditingController();
  final _abastCtrl = TextEditingController();
  DateTime _dataTotalSelecionada = DateTime.now();

  @override
  void initState() {
    super.initState();
    _atual = widget.atual; _meta = widget.meta; _abast = widget.abastecimento;
    _viagens = List.from(widget.viagens);
  }

  @override
  void didUpdateWidget(HojeTab old) {
    super.didUpdateWidget(old);
    if (old.atual != widget.atual) _atual = widget.atual;
    if (old.meta != widget.meta) _meta = widget.meta;
    if (old.abastecimento != widget.abastecimento) _abast = widget.abastecimento;
    if (old.viagens != widget.viagens) _viagens = List.from(widget.viagens);
  }

  void _notify() => widget.onChanged(_atual, _meta, _abast, _viagens);
  String _fmt(double v) => 'R\$ ${v.toStringAsFixed(2).replaceAll('.', ',')}';
  double get _pct => _meta > 0 ? (_atual / _meta).clamp(0, 1) : 0;
  double get _falta => (_meta - _atual).clamp(0, double.infinity);
  double get _liquido => (_atual - _abast).clamp(0, double.infinity);
  double get _media {
    final normais = _viagens.where((v) => v['promo'] != true).toList();
    return normais.isEmpty ? 0 : _atual / normais.length;
  }

  void _addViagem() {
    final val = double.tryParse(_corridaCtrl.text.replaceAll(',', '.'));
    if (val == null || val <= 0) return;
    final isPromo = _ehPromocao;
    setState(() {
      _atual += val;
      _viagens.add({'val': val, 'hora': TimeOfDay.now().format(context), 'promo': isPromo});
      _ehPromocao = false;
    });
    _corridaCtrl.clear(); _notify();
  }

  void _removeViagem(int idx) {
    final val = (_viagens[idx]['val'] as num).toDouble();
    showDialog(context: context, builder: (_) => AlertDialog(
      title: const Text('Excluir viagem?'),
      content: Text('Viagem #${idx + 1} de ${_fmt(val)} será removida.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        TextButton(onPressed: () {
          setState(() { _atual = (_atual - val).clamp(0, double.infinity); _viagens.removeAt(idx); });
          _notify(); Navigator.pop(context);
        }, child: const Text('Excluir', style: TextStyle(color: Colors.red))),
      ],
    ));
  }

  void _setMeta() {
    final val = double.tryParse(_metaCtrl.text.replaceAll(',', '.'));
    if (val == null || val <= 0) return;
    setState(() => _meta = val); _metaCtrl.clear(); _notify();
    _showSnack('Meta atualizada para ${_fmt(val)}');
  }

  void _zerar() {
    showDialog(context: context, builder: (_) => AlertDialog(
      title: const Text('Zerar tudo?'),
      content: const Text('Apaga o saldo, viagens e abastecimento de hoje.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        TextButton(onPressed: () {
          setState(() { _atual = 0; _viagens = []; _abast = 0; });
          _notify(); Navigator.pop(context);
        }, child: const Text('Zerar', style: TextStyle(color: Colors.red))),
      ],
    ));
  }

  Future<void> _selecionarData() async {
    final picked = await showDatePicker(
      context: context, initialDate: _dataTotalSelecionada,
      firstDate: DateTime(2020), lastDate: DateTime.now(), locale: const Locale('pt', 'BR'));
    if (picked != null) setState(() => _dataTotalSelecionada = picked);
  }

  String _fmtData(DateTime d) => '${d.day.toString().padLeft(2,'0')}/${d.month.toString().padLeft(2,'0')}/${d.year}';

  void _encerrarDia() {
    final km = double.tryParse(_kmCtrl.text.replaceAll(',', '.')) ?? 0;
    final abastVal = double.tryParse(_abastCtrl.text.replaceAll(',', '.')) ?? 0;
    double horas = _parseHoras(_horasCtrl.text.trim());

    if (_modoTotal) {
      final total = double.tryParse(_totalCtrl.text.replaceAll(',', '.'));
      final nVia = int.tryParse(_nViaCtrl.text.trim());
      if (total == null || total <= 0) { _showSnack('Informe o total ganho.'); return; }
      if (nVia == null || nVia <= 0) { _showSnack('Informe o número de viagens.'); return; }
      final metaVal = double.tryParse(_metaTotalCtrl.text.replaceAll(',', '.'));
      if (metaVal != null && metaVal > 0) _meta = metaVal;
      final dt = _dataTotalSelecionada;
      showDialog(context: context, builder: (_) => AlertDialog(
        title: const Text('Encerrar o dia?'),
        content: Text('Salvar ${_fmt(total)} em $nVia viagens em ${_fmtData(dt)}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          TextButton(onPressed: () {
            widget.onEncerrarDia({
              'data': _fmtData(dt), 'dataISO': dt.toIso8601String(),
              'semana': _diaSemana(dt.weekday), 'total': total, 'meta': _meta,
              'viagens': nVia, 'km': km, 'horas': horas, 'abastecimento': abastVal,
              'liquido': total - abastVal, 'bateu': total >= _meta, 'modoTotal': true,
            });
            _totalCtrl.clear(); _nViaCtrl.clear(); _metaTotalCtrl.clear();
            _kmCtrl.clear(); _horasCtrl.clear(); _abastCtrl.clear();
            Navigator.pop(context); _showSnack('Dia ${_fmtData(dt)} salvo no Diário!');
          }, child: const Text('Encerrar', style: TextStyle(color: Color(0xFF1D9E75)))),
        ],
      ));
    } else {
      if (_viagens.isEmpty) { _showSnack('Adicione pelo menos uma viagem antes de encerrar.'); return; }
      final totalAbast = _abast + abastVal;
      final now = DateTime.now();
      showDialog(context: context, builder: (_) => AlertDialog(
        title: const Text('Encerrar o dia?'),
        content: Text('Salvar ${_fmt(_atual)} em ${_viagens.length} viagens no Diário?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          TextButton(onPressed: () {
            widget.onEncerrarDia({
              'data': _fmtData(now), 'dataISO': now.toIso8601String(),
              'semana': _diaSemana(now.weekday), 'total': _atual, 'meta': _meta,
              'viagens': _viagens.length, 'km': km, 'horas': horas,
              'abastecimento': totalAbast, 'liquido': _atual - totalAbast,
              'bateu': _atual >= _meta, 'modoTotal': false,
              'historicoViagens': List.from(_viagens),
            });
            _kmCtrl.clear(); _horasCtrl.clear(); _abastCtrl.clear();
            Navigator.pop(context); _showSnack('Dia encerrado e salvo no Diário!');
          }, child: const Text('Encerrar', style: TextStyle(color: Color(0xFF1D9E75)))),
        ],
      ));
    }
  }

  double _parseHoras(String ht) {
    if (ht.isEmpty) return 0;
    final c = ht.replaceAll('h', ':').replaceAll(',', '.');
    if (c.contains(':')) {
      final p = c.split(':');
      return (double.tryParse(p[0]) ?? 0) + (double.tryParse(p.length > 1 ? p[1] : '0') ?? 0) / 60;
    }
    return double.tryParse(c) ?? 0;
  }

  String _diaSemana(int w) => ['Segunda','Terça','Quarta','Quinta','Sexta','Sábado','Domingo'][w - 1];
  void _showSnack(String msg) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(msg), duration: const Duration(seconds: 3)));

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: Column(children: [
        Row(children: [
          _statCard('Saldo bruto', _fmt(_atual), const Color(0xFF1D9E75), cs),
          const SizedBox(width: 6),
          _statCard('Abastec.', _abast > 0 ? '-${_fmt(_abast)}' : 'R\$ 0,00', const Color(0xFF993C1D), cs),
          const SizedBox(width: 6),
          _statCard('Líquido', _fmt(_liquido), const Color(0xFF185FA5), cs),
          const SizedBox(width: 6),
          _statCard('Viagens', '${_viagens.where((v) => v['promo'] != true).length}', cs.onSurface, cs),
        ]),
        const SizedBox(height: 12),
        _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('Meta: ${_fmt(_meta)}', style: TextStyle(fontSize: 13, color: cs.onSurface.withOpacity(0.6))),
            Text(_falta <= 0 ? 'Meta atingida!' : 'falta ${_fmt(_falta)}',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500,
                    color: _falta <= 0 ? const Color(0xFF1D9E75) : const Color(0xFF993C1D))),
          ]),
          const SizedBox(height: 10),
          ClipRRect(borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(value: _pct, minHeight: 10,
                backgroundColor: cs.onSurface.withOpacity(0.1), color: const Color(0xFF1D9E75))),
          const SizedBox(height: 6),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('${(_pct * 100).toStringAsFixed(0)}%',
                style: const TextStyle(fontSize: 11, color: Color(0xFF1D9E75), fontWeight: FontWeight.w500)),
            Text(_fmt(_meta), style: TextStyle(fontSize: 11, color: cs.onSurface.withOpacity(0.45))),
          ]),
        ])),
        const SizedBox(height: 12),
        _card(Column(children: [
          Align(alignment: Alignment.centerLeft,
            child: Text('Registrar viagens', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: cs.onSurface.withOpacity(0.6)))),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(color: isDark ? const Color(0xFF333333) : const Color(0xFFEEEEEE), borderRadius: BorderRadius.circular(8)),
            padding: const EdgeInsets.all(3),
            child: Row(children: [
              _toggleBtn('Uma por uma', !_modoTotal, () => setState(() => _modoTotal = false), cs, isDark),
              _toggleBtn('Total do dia', _modoTotal, () => setState(() => _modoTotal = true), cs, isDark),
            ]),
          ),
          const SizedBox(height: 10),
          if (!_modoTotal) ...[
            Row(children: [
              Expanded(child: _inputField(_corridaCtrl, 'Valor da viagem (R\$)', '18.50', cs)),
              const SizedBox(width: 8),
              Expanded(child: _inputField(_metaCtrl, 'Meta (R\$)', '500', cs)),
            ]),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => setState(() => _ehPromocao = !_ehPromocao),
              child: Row(children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 20, height: 20,
                  decoration: BoxDecoration(
                    color: _ehPromocao ? const Color(0xFFBA7517) : Colors.transparent,
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(color: _ehPromocao ? const Color(0xFFBA7517) : cs.onSurface.withOpacity(0.26), width: 1.5),
                  ),
                  child: _ehPromocao ? const Icon(Icons.check, size: 14, color: Colors.white) : null,
                ),
                const SizedBox(width: 8),
                Text('É promoção/bônus', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500,
                    color: _ehPromocao ? const Color(0xFFBA7517) : cs.onSurface.withOpacity(0.5))),
                const SizedBox(width: 6),
                Text('(não conta nas viagens)', style: TextStyle(fontSize: 11, color: cs.onSurface.withOpacity(0.38))),
              ]),
            ),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: _btn('+ Viagem', const Color(0xFF1D9E75), Colors.white, _addViagem, isDark)),
              const SizedBox(width: 6),
              Expanded(child: _btn('Salvar meta', null, null, _setMeta, isDark, isOutline: true)),
              const SizedBox(width: 6),
              Expanded(child: _btn('Zerar', null, const Color(0xFF993C1D), _zerar, isDark, border: const Color(0xFFD85A30))),
            ]),
          ] else ...[
            GestureDetector(
              onTap: _selecionarData,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF5F5F0),
                  border: Border.all(color: cs.onSurface.withOpacity(0.26), width: 0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(children: [
                  Icon(Icons.calendar_today_outlined, size: 16, color: const Color(0xFF1D9E75)),
                  const SizedBox(width: 8),
                  Text(_fmtData(_dataTotalSelecionada),
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: cs.onSurface)),
                  const Spacer(),
                  Text('alterar', style: TextStyle(fontSize: 11, color: cs.onSurface.withOpacity(0.38))),
                ]),
              ),
            ),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: _inputField(_totalCtrl, 'Total ganho (R\$)', 'ex: 280.00', cs)),
              const SizedBox(width: 8),
              Expanded(child: _inputField(_nViaCtrl, 'Nº de viagens', 'ex: 15', cs)),
            ]),
            const SizedBox(height: 8),
            _inputField(_metaTotalCtrl, 'Meta do dia (R\$)', '500', cs),
            const SizedBox(height: 6),
            Text('os dados do expediente serão preenchidos na seção abaixo',
                style: TextStyle(fontSize: 11, color: cs.onSurface.withOpacity(0.38))),
          ],
        ])),
        const SizedBox(height: 12),
        _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Encerrar o dia', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: cs.onSurface.withOpacity(0.6))),
          const SizedBox(height: 10),
          Container(height: 0.5, color: cs.onSurface.withOpacity(0.12)),
          const SizedBox(height: 10),
          Text('Dados do expediente', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: cs.onSurface.withOpacity(0.5))),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: _inputField(_kmCtrl, 'Km rodados', 'ex: 187', cs)),
            const SizedBox(width: 8),
            Expanded(child: _inputField(_horasCtrl, 'Horas trabalhadas', 'ex: 8h30', cs)),
          ]),
          const SizedBox(height: 8),
          SizedBox(width: MediaQuery.of(context).size.width / 2 - 20,
            child: _inputField(_abastCtrl, 'Abastecimento (R\$)', 'ex: 80.00', cs)),
          const SizedBox(height: 12),
          Container(height: 0.5, color: cs.onSurface.withOpacity(0.12)),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: _encerrarDia,
            child: Container(
              width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 13),
              decoration: BoxDecoration(
                color: isDark ? Colors.white : const Color(0xFF1D9E75),
                borderRadius: BorderRadius.circular(10)),
              child: Center(child: Text('+ Encerrar dia e salvar',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500,
                      color: isDark ? Colors.black : Colors.white))),
            ),
          ),
          const SizedBox(height: 6),
          Center(child: Text('salva no Diário e zera o contador de hoje',
              style: TextStyle(fontSize: 11, color: cs.onSurface.withOpacity(0.38)))),
        ])),
        const SizedBox(height: 12),
        if (!_modoTotal && _viagens.isNotEmpty)
          _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('Viagens de hoje', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: cs.onSurface.withOpacity(0.6))),
              Text(() {
                final normais = _viagens.where((v) => v['promo'] != true).length;
                final promos = _viagens.where((v) => v['promo'] == true).length;
                return '$normais viagens${promos > 0 ? ' · $promos promo' : ''} · ${_fmt(_media)}/viag.';
              }(), style: TextStyle(fontSize: 11, color: cs.onSurface.withOpacity(0.38))),
            ]),
            const SizedBox(height: 10),
            ..._viagens.reversed.take(30).toList().asMap().entries.map((e) {
              final orig = _viagens.length - 1 - e.key;
              final v = e.value;
              final isPromo = v['promo'] == true;
              final numNormal = isPromo ? 0 : _viagens.sublist(0, orig + 1).where((x) => x['promo'] != true).length;
              return Padding(padding: const EdgeInsets.only(bottom: 6),
                child: Row(children: [
                  isPromo
                    ? Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: const Color(0xFFFAEEDA), borderRadius: BorderRadius.circular(99)),
                        child: const Text('promo', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: Color(0xFF854F0B))))
                    : Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: const Color(0xFF9FE1CB), borderRadius: BorderRadius.circular(99)),
                        child: Text('#$numNormal', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Color(0xFF085041)))),
                  const SizedBox(width: 8),
                  Text(v['hora'] ?? '', style: TextStyle(fontSize: 11, color: cs.onSurface.withOpacity(0.38))),
                  const Spacer(),
                  Text('+${_fmt((v['val'] as num).toDouble())}',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500,
                          color: isPromo ? const Color(0xFFBA7517) : const Color(0xFF1D9E75))),
                  const SizedBox(width: 8),
                  GestureDetector(onTap: () => _removeViagem(orig),
                    child: Container(padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(color: const Color(0xFFFAECE7), borderRadius: BorderRadius.circular(6)),
                      child: const Icon(Icons.close, size: 14, color: Color(0xFF993C1D)))),
                ]));
            }),
          ])),
      ]),
    );
  }

  Widget _card(Widget child) => Builder(builder: (ctx) {
    final isDark = Theme.of(ctx).brightness == Brightness.dark;
    final cs = Theme.of(ctx).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF252525) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.onSurface.withOpacity(0.1), width: 0.5)),
      child: child);
  });

  Widget _statCard(String label, String value, Color color, ColorScheme cs) => Expanded(
    child: Container(padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: cs.surfaceContainerHighest, borderRadius: BorderRadius.circular(10)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(fontSize: 9, color: cs.onSurface.withOpacity(0.5))),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: color)),
      ])));

  Widget _toggleBtn(String label, bool active, VoidCallback onTap, ColorScheme cs, bool isDark) => Expanded(
    child: GestureDetector(onTap: onTap,
      child: AnimatedContainer(duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 7),
        decoration: BoxDecoration(
          color: active ? (isDark ? const Color(0xFF444444) : Colors.white) : Colors.transparent,
          borderRadius: BorderRadius.circular(6)),
        child: Text(label, textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500,
                color: active ? cs.onSurface : cs.onSurface.withOpacity(0.45))))));

  Widget _inputField(TextEditingController ctrl, String label, String hint, ColorScheme cs) =>
    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(fontSize: 11, color: cs.onSurface.withOpacity(0.6))),
      const SizedBox(height: 4),
      TextField(controller: ctrl,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(fontSize: 13, color: cs.onSurface.withOpacity(0.38)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: cs.onSurface.withOpacity(0.3), width: 0.5)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: cs.onSurface.withOpacity(0.3), width: 0.5)))),
    ]);

  Widget _btn(String label, Color? bg, Color? fg, VoidCallback onTap, bool isDark,
      {Color? border, bool isOutline = false}) {
    Color effectiveBg;
    Color effectiveFg;
    if (bg == const Color(0xFF1D9E75)) {
      effectiveBg = isDark ? Colors.white : const Color(0xFF1D9E75);
      effectiveFg = isDark ? Colors.black : Colors.white;
    } else if (isOutline) {
      effectiveBg = isDark ? const Color(0xFF2A2A2A) : Colors.white;
      effectiveFg = Theme.of(context).colorScheme.onSurface;
    } else {
      effectiveBg = isDark ? const Color(0xFF2A2A2A) : Colors.white;
      effectiveFg = fg ?? Theme.of(context).colorScheme.onSurface;
    }
    return GestureDetector(onTap: onTap,
      child: Container(padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(color: effectiveBg, borderRadius: BorderRadius.circular(8),
            border: Border.all(color: border ?? Theme.of(context).colorScheme.onSurface.withOpacity(0.2), width: 0.5)),
        child: Center(child: Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: effectiveFg)))));
  }
}

// ─── ABA DIÁRIO ───────────────────────────────────────────────────────────────

class DiarioTab extends StatefulWidget {
  final List<Map<String, dynamic>> dias;
  final Function(int) onDeleteDia;
  const DiarioTab({super.key, required this.dias, required this.onDeleteDia});
  @override State<DiarioTab> createState() => _DiarioTabState();
}

class _DiarioTabState extends State<DiarioTab> {
  DateTime? _filtroData;

  String _fmt(double v) => 'R\$ ${v.toStringAsFixed(2).replaceAll('.', ',')}';
  String _fmtH(double h) { final hh = h.floor(); final mm = ((h-hh)*60).round(); return mm > 0 ? '${hh}h${mm.toString().padLeft(2,'0')}' : '${hh}h'; }
  String _fmtDate(DateTime d) => '${d.day.toString().padLeft(2,'0')}/${d.month.toString().padLeft(2,'0')}/${d.year}';

  List<Map<String, dynamic>> get _diasFiltrados {
    if (_filtroData == null) return widget.dias;
    final alvo = _fmtDate(_filtroData!);
    return widget.dias.where((d) => (d['data'] as String? ?? '') == alvo).toList();
  }

  Future<void> _selecionarFiltro() async {
    final picked = await showDatePicker(
      context: context, initialDate: _filtroData ?? DateTime.now(),
      firstDate: DateTime(2020), lastDate: DateTime.now(), locale: const Locale('pt', 'BR'));
    if (picked != null) setState(() => _filtroData = picked);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dias = _diasFiltrados;

    if (widget.dias.isEmpty) return Center(child: Text('Nenhum dia registrado ainda.\nEncerre o primeiro dia na aba Hoje!',
        textAlign: TextAlign.center, style: TextStyle(color: cs.onSurface.withOpacity(0.38), fontSize: 14)));

    final batidas = widget.dias.where((d) => d['bateu'] == true).length;
    final pct = (batidas / widget.dias.length * 100).round();
    final kmTotal = widget.dias.fold<double>(0, (s, d) => s + (d['km'] as num? ?? 0).toDouble());

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: Column(children: [
        Row(children: [
          _mini('dias', '${widget.dias.length}', cs.onSurface, cs, isDark),
          const SizedBox(width: 6),
          _mini('metas', '$batidas/${widget.dias.length}', const Color(0xFF1D9E75), cs, isDark),
          const SizedBox(width: 6),
          _mini('aproveit.', '$pct%', const Color(0xFFBA7517), cs, isDark),
          const SizedBox(width: 6),
          _mini('km total', '${kmTotal.toStringAsFixed(0)}', const Color(0xFF185FA5), cs, isDark),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: GestureDetector(
            onTap: _selecionarFiltro,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: _filtroData != null ? const Color(0xFFE1F5EE) : (isDark ? const Color(0xFF252525) : Colors.white),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _filtroData != null ? const Color(0xFF5DCAA5) : cs.onSurface.withOpacity(0.12), width: 0.5),
              ),
              child: Row(children: [
                Icon(Icons.calendar_today_outlined, size: 15,
                    color: _filtroData != null ? const Color(0xFF085041) : cs.onSurface.withOpacity(0.5)),
                const SizedBox(width: 8),
                Text(_filtroData != null ? _fmtDate(_filtroData!) : 'Filtrar por data',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500,
                        color: _filtroData != null ? const Color(0xFF085041) : cs.onSurface.withOpacity(0.6))),
              ]),
            ),
          )),
          if (_filtroData != null) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => setState(() => _filtroData = null),
              child: Container(padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: cs.surfaceContainerHighest, borderRadius: BorderRadius.circular(8)),
                child: Icon(Icons.close, size: 16, color: cs.onSurface.withOpacity(0.5))),
            ),
          ],
        ]),
        const SizedBox(height: 10),
        if (dias.isEmpty)
          Container(padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: isDark ? const Color(0xFF252525) : Colors.white,
                borderRadius: BorderRadius.circular(16), border: Border.all(color: cs.onSurface.withOpacity(0.1), width: 0.5)),
            child: Center(child: Text('Nenhum registro em ${_fmtDate(_filtroData!)}.',
                style: TextStyle(color: cs.onSurface.withOpacity(0.38)))))
        else
          ...dias.asMap().entries.map((e) {
            final i = e.key; final d = e.value;
            final total = (d['total'] as num).toDouble();
            final meta = (d['meta'] as num).toDouble();
            final km = (d['km'] as num? ?? 0).toDouble();
            final horas = (d['horas'] as num? ?? 0).toDouble();
            final viagens = d['viagens'] as int? ?? 0;
            final abast = (d['abastecimento'] as num? ?? 0).toDouble();
            final liquido = (d['liquido'] as num? ?? total).toDouble();
            final bateu = d['bateu'] as bool? ?? false;
            final modoTotal = d['modoTotal'] as bool? ?? true;
            final historico = d['historicoViagens'] as List?;
            final pctDia = meta > 0 ? (total / meta).clamp(0.0, 1.0) : 0.0;
            final ganhoH = horas > 0 ? total / horas : 0.0;
            final ganhoKm = km > 0 ? total / km : 0.0;
            final temHistorico = !modoTotal && historico != null && historico.isNotEmpty;

            return Padding(padding: const EdgeInsets.only(bottom: 10),
              child: GestureDetector(
                onTap: temHistorico ? () => _abrirHistorico(context, d, historico) : null,
                child: Container(padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF252525) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: temHistorico ? const Color(0xFF9FE1CB) : cs.onSurface.withOpacity(0.1),
                      width: temHistorico ? 1.0 : 0.5)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Text(d['data'] ?? '', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: cs.onSurface)),
                          if (temHistorico) ...[
                            const SizedBox(width: 6),
                            const Icon(Icons.expand_more, size: 16, color: Color(0xFF1D9E75)),
                          ],
                        ]),
                        Text(d['semana'] ?? '', style: TextStyle(fontSize: 10, color: cs.onSurface.withOpacity(0.38))),
                      ]),
                      Row(children: [
                        Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                              color: bateu ? const Color(0xFFE1F5EE) : const Color(0xFFFAECE7),
                              borderRadius: BorderRadius.circular(99)),
                          child: Text(bateu ? 'Meta batida' : 'Não bateu',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500,
                                  color: bateu ? const Color(0xFF085041) : const Color(0xFF712B13)))),
                        const SizedBox(width: 6),
                        GestureDetector(onTap: () => _confirmarExcluir(context, i, d),
                          child: Container(padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(color: cs.surfaceContainerHighest, borderRadius: BorderRadius.circular(6)),
                            child: Icon(Icons.close, size: 13, color: cs.onSurface.withOpacity(0.38)))),
                      ]),
                    ]),
                    const SizedBox(height: 8),
                    Container(height: 0.5, color: cs.onSurface.withOpacity(0.12)),
                    const SizedBox(height: 8),
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Text('total bruto', style: TextStyle(fontSize: 11, color: cs.onSurface.withOpacity(0.5))),
                      Text(_fmt(total), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500,
                          color: bateu ? const Color(0xFF1D9E75) : const Color(0xFF993C1D))),
                    ]),
                    if (abast > 0) ...[
                      const SizedBox(height: 3),
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        Text('abastecimento', style: TextStyle(fontSize: 11, color: cs.onSurface.withOpacity(0.5))),
                        Text('-${_fmt(abast)}', style: const TextStyle(fontSize: 12, color: Color(0xFF993C1D))),
                      ]),
                      const SizedBox(height: 3),
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        Text('líquido', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: cs.onSurface.withOpacity(0.6))),
                        Text(_fmt(liquido), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF185FA5))),
                      ]),
                    ],
                    const SizedBox(height: 3),
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Text('meta do dia', style: TextStyle(fontSize: 11, color: cs.onSurface.withOpacity(0.5))),
                      Text(_fmt(meta), style: TextStyle(fontSize: 12, color: cs.onSurface)),
                    ]),
                    const SizedBox(height: 3),
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Text('viagens · km · horas', style: TextStyle(fontSize: 11, color: cs.onSurface.withOpacity(0.5))),
                      Text('$viagens${km > 0 ? ' · ${km.toStringAsFixed(0)}km' : ''}${horas > 0 ? ' · ${_fmtH(horas)}' : ''}',
                          style: TextStyle(fontSize: 12, color: cs.onSurface)),
                    ]),
                    if (km > 0 || horas > 0) ...[
                      const SizedBox(height: 10),
                      Row(children: [
                        if (horas > 0) Expanded(child: _mediaCard('ganho por hora', 'R\$ ${ganhoH.toStringAsFixed(2).replaceAll('.', ',')}/h', cs, isDark)),
                        if (horas > 0 && km > 0) const SizedBox(width: 8),
                        if (km > 0) Expanded(child: _mediaCard('ganho por km', 'R\$ ${ganhoKm.toStringAsFixed(2).replaceAll('.', ',')}/km', cs, isDark)),
                      ]),
                    ],
                    const SizedBox(height: 10),
                    ClipRRect(borderRadius: BorderRadius.circular(99),
                      child: LinearProgressIndicator(value: pctDia, minHeight: 6,
                        backgroundColor: cs.onSurface.withOpacity(0.1),
                        color: bateu ? const Color(0xFF1D9E75) : const Color(0xFF993C1D))),
                    const SizedBox(height: 4),
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Text('${(pctDia * 100).toStringAsFixed(0)}%',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500,
                              color: bateu ? const Color(0xFF1D9E75) : const Color(0xFF993C1D))),
                      Text(_fmt(meta), style: TextStyle(fontSize: 10, color: cs.onSurface.withOpacity(0.38))),
                    ]),
                    if (temHistorico) ...[
                      const SizedBox(height: 8),
                      Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(color: const Color(0xFFE1F5EE), borderRadius: BorderRadius.circular(8)),
                        child: const Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.touch_app_outlined, size: 13, color: Color(0xFF085041)),
                          SizedBox(width: 4),
                          Text('toque para ver o histórico de viagens', style: TextStyle(fontSize: 10, color: Color(0xFF085041))),
                        ])),
                    ],
                  ])),
              ));
          }),
      ]),
    );
  }

  void _abrirHistorico(BuildContext context, Map<String, dynamic> d, List historico) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context, isScrollControlled: true, isDismissible: true, enableDrag: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => GestureDetector(
        onTap: () => Navigator.pop(sheetCtx),
        behavior: HitTestBehavior.opaque,
        child: DraggableScrollableSheet(
          initialChildSize: 0.6, maxChildSize: 0.9, minChildSize: 0.3,
          builder: (_, ctrl) => GestureDetector(
            onTap: () {},
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF252525) : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
              child: Column(children: [
                Container(margin: const EdgeInsets.only(top: 12), width: 40, height: 4,
                    decoration: BoxDecoration(color: cs.onSurface.withOpacity(0.2), borderRadius: BorderRadius.circular(99))),
                Padding(padding: const EdgeInsets.all(16),
                  child: Row(children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${d['data']} · ${d['semana']}',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: cs.onSurface)),
                      Text('${historico.length} viagens · R\$ ${(d['total'] as num).toStringAsFixed(2).replaceAll('.', ',')}',
                          style: TextStyle(fontSize: 12, color: cs.onSurface.withOpacity(0.5))),
                    ])),
                  ])),
                Container(height: 0.5, color: cs.onSurface.withOpacity(0.12)),
                Expanded(child: ListView.builder(
                  controller: ctrl, padding: const EdgeInsets.all(16),
                  itemCount: historico.length,
                  itemBuilder: (_, i) {
                    final v = historico[i] as Map;
                    final isPromo = v['promo'] == true;
                    return Padding(padding: const EdgeInsets.only(bottom: 8),
                      child: Row(children: [
                        isPromo
                          ? Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(color: const Color(0xFFFAEEDA), borderRadius: BorderRadius.circular(99)),
                              child: const Text('promo', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: Color(0xFF854F0B))))
                          : Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(color: const Color(0xFF9FE1CB), borderRadius: BorderRadius.circular(99)),
                              child: Text('#${i + 1}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Color(0xFF085041)))),
                        const SizedBox(width: 10),
                        Text(v['hora']?.toString() ?? '', style: TextStyle(fontSize: 12, color: cs.onSurface.withOpacity(0.5))),
                        const Spacer(),
                        Text('+R\$ ${(v['val'] as num).toStringAsFixed(2).replaceAll('.', ',')}',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500,
                                color: isPromo ? const Color(0xFFBA7517) : const Color(0xFF1D9E75))),
                      ]));
                  },
                )),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  void _confirmarExcluir(BuildContext context, int i, Map d) {
    showDialog(context: context, builder: (_) => AlertDialog(
      title: const Text('Excluir dia?'),
      content: Text('O registro de ${d['data']} será apagado.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        TextButton(onPressed: () { widget.onDeleteDia(i); Navigator.pop(context); },
            child: const Text('Excluir', style: TextStyle(color: Colors.red))),
      ],
    ));
  }

  Widget _mini(String label, String val, Color color, ColorScheme cs, bool isDark) => Expanded(
    child: Container(padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: cs.surfaceContainerHighest, borderRadius: BorderRadius.circular(10)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(fontSize: 9, color: cs.onSurface.withOpacity(0.5))),
        const SizedBox(height: 2),
        Text(val, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: color)),
      ])));

  Widget _mediaCard(String label, String val, ColorScheme cs, bool isDark) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: BoxDecoration(color: cs.surfaceContainerHighest, borderRadius: BorderRadius.circular(8)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(fontSize: 9, color: cs.onSurface.withOpacity(0.5))),
      const SizedBox(height: 2),
      Text(val, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF1D9E75))),
    ]));
}

// ─── ABA RESUMO ───────────────────────────────────────────────────────────────

class ResumoTab extends StatefulWidget {
  final List<Map<String, dynamic>> dias;
  const ResumoTab({super.key, required this.dias});
  @override State<ResumoTab> createState() => _ResumoTabState();
}

class _ResumoTabState extends State<ResumoTab> {
  DateTime? _inicio, _fim;
  DateTime _calMes = DateTime.now();
  bool _showCal = false;
  String _quickSel = '30';
  DateTime? _tapInicio;

  @override
  void initState() { super.initState(); _aplicarQuick('30'); }

  void _aplicarQuick(String q) {
    final now = DateTime.now();
    setState(() {
      _quickSel = q; _tapInicio = null; _fim = now;
      if (q == 'hoje') _inicio = DateTime(now.year, now.month, now.day);
      else if (q == 'mes') _inicio = DateTime(now.year, now.month, 1);
      else if (q == 'ano') _inicio = DateTime(now.year, 1, 1);
      else if (q == 'tudo') _inicio = DateTime(2020, 1, 1);
      else { final days = int.tryParse(q) ?? 30; _inicio = now.subtract(Duration(days: days)); }
    });
  }

  void _tapDia(DateTime dia) {
    setState(() {
      if (_tapInicio == null) {
        _tapInicio = DateTime(dia.year, dia.month, dia.day);
        _inicio = _tapInicio; _fim = _tapInicio; _quickSel = '';
      } else {
        final fim = DateTime(dia.year, dia.month, dia.day);
        if (fim.isBefore(_tapInicio!)) { _inicio = fim; _fim = _tapInicio; }
        else { _inicio = _tapInicio; _fim = fim; }
        _tapInicio = null; _quickSel = '';
      }
    });
  }

  List<Map<String, dynamic>> get _diasFiltrados {
    if (_inicio == null || _fim == null) return widget.dias;
    final fimDia = DateTime(_fim!.year, _fim!.month, _fim!.day, 23, 59, 59);
    return widget.dias.where((d) {
      try {
        final iso = d['dataISO'] as String?;
        DateTime dt;
        if (iso != null) { dt = DateTime.parse(iso); }
        else { final parts = (d['data'] as String).split('/'); dt = DateTime(int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0])); }
        return !dt.isBefore(_inicio!) && !dt.isAfter(fimDia);
      } catch (_) { return true; }
    }).toList();
  }

  String _fmt(double v) => 'R\$ ${v.toStringAsFixed(2).replaceAll('.', ',')}';
  String _fmtH(double h) { final hh = h.floor(); final mm = ((h-hh)*60).round(); return mm > 0 ? '${hh}h${mm.toString().padLeft(2,'0')}' : '${hh}h'; }
  String _fmtDate(DateTime d) => '${d.day.toString().padLeft(2,'0')}/${d.month.toString().padLeft(2,'0')}/${d.year}';
  bool _isStart(DateTime d) => _inicio != null && d.year == _inicio!.year && d.month == _inicio!.month && d.day == _inicio!.day;
  bool _isEnd(DateTime d) => _fim != null && d.year == _fim!.year && d.month == _fim!.month && d.day == _fim!.day;
  bool _isInRange(DateTime d) => _inicio != null && _fim != null && !d.isBefore(_inicio!) && !d.isAfter(_fim!);
  bool _isToday(DateTime d) { final n = DateTime.now(); return d.year == n.year && d.month == n.month && d.day == n.day; }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dias = _diasFiltrados;
    final meses = ['Janeiro','Fevereiro','Março','Abril','Maio','Junho','Julho','Agosto','Setembro','Outubro','Novembro','Dezembro'];

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: Column(children: [
        GestureDetector(
          onTap: () => setState(() => _showCal = !_showCal),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: _showCal ? const Color(0xFFE1F5EE) : (isDark ? const Color(0xFF252525) : Colors.white),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _showCal ? const Color(0xFF5DCAA5) : cs.onSurface.withOpacity(0.12), width: 0.5),
            ),
            child: Row(children: [
              Icon(Icons.calendar_month_outlined, size: 16, color: _showCal ? const Color(0xFF085041) : cs.onSurface.withOpacity(0.6)),
              const SizedBox(width: 8),
              Expanded(child: Text(
                _inicio != null && _fim != null ? '${_fmtDate(_inicio!)}  →  ${_fmtDate(_fim!)}' : 'Selecionar período',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500,
                    color: _showCal ? const Color(0xFF085041) : cs.onSurface),
              )),
              Icon(_showCal ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, size: 18, color: cs.onSurface.withOpacity(0.38)),
            ]),
          ),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(scrollDirection: Axis.horizontal,
          child: Row(children: [
            for (final q in [('hoje','Hoje'),('7','7 dias'),('30','30 dias'),('mes','Este mês'),('ano','Este ano'),('tudo','Todo período')])
              Padding(padding: const EdgeInsets.only(right: 6),
                child: GestureDetector(onTap: () => _aplicarQuick(q.$1),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _quickSel == q.$1 ? const Color(0xFF1D9E75) : cs.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(q.$2, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500,
                        color: _quickSel == q.$1 ? Colors.white : cs.onSurface.withOpacity(0.6)))))),
          ])),
        const SizedBox(height: 8),
        if (_showCal) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF252525) : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: cs.onSurface.withOpacity(0.1), width: 0.5)),
            child: Column(children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                GestureDetector(
                  onTap: () => setState(() => _calMes = DateTime(_calMes.year, _calMes.month - 1)),
                  child: Padding(padding: const EdgeInsets.all(6), child: Icon(Icons.chevron_left, size: 22, color: cs.onSurface.withOpacity(0.6)))),
                Text('${meses[_calMes.month - 1]} ${_calMes.year}',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: cs.onSurface)),
                GestureDetector(
                  onTap: () => setState(() => _calMes = DateTime(_calMes.year, _calMes.month + 1)),
                  child: Padding(padding: const EdgeInsets.all(6), child: Icon(Icons.chevron_right, size: 22, color: cs.onSurface.withOpacity(0.6)))),
              ]),
              const SizedBox(height: 10),
              Row(children: ['D','S','T','Q','Q','S','S'].map((d) => Expanded(
                child: Center(child: Text(d, style: TextStyle(fontSize: 11, color: cs.onSurface.withOpacity(0.38), fontWeight: FontWeight.w500))))).toList()),
              const SizedBox(height: 4),
              Builder(builder: (_) {
                final firstDay = DateTime(_calMes.year, _calMes.month, 1);
                final daysInMonth = DateTime(_calMes.year, _calMes.month + 1, 0).day;
                final startWeekday = firstDay.weekday % 7;
                final cells = startWeekday + daysInMonth;
                return GridView.builder(
                  shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7, childAspectRatio: 1),
                  itemCount: cells,
                  itemBuilder: (_, idx) {
                    if (idx < startWeekday) return const SizedBox();
                    final dia = DateTime(_calMes.year, _calMes.month, idx - startWeekday + 1);
                    final start = _isStart(dia);
                    final end = _isEnd(dia) && !start;
                    final inRange = _isInRange(dia) && !start && !end;
                    final today = _isToday(dia);
                    Color bg = Colors.transparent;
                    Color fg = cs.onSurface;
                    BorderRadius br = BorderRadius.circular(6);
                    if (start) { bg = const Color(0xFF1D9E75); fg = Colors.white; br = BorderRadius.circular(99); }
                    else if (end) { bg = const Color(0xFF1D9E75); fg = Colors.white; br = BorderRadius.circular(99); }
                    else if (inRange) { bg = const Color(0xFFE1F5EE); fg = const Color(0xFF085041); br = BorderRadius.zero; }
                    else if (today) { bg = const Color(0xFFB5D4F4); fg = const Color(0xFF0C447C); br = BorderRadius.circular(99); }
                    return GestureDetector(
                      onTap: () => _tapDia(dia),
                      child: Container(decoration: BoxDecoration(color: bg, borderRadius: br),
                        child: Center(child: Text('${dia.day}',
                            style: TextStyle(fontSize: 11, fontWeight: (start || end) ? FontWeight.w700 : FontWeight.normal, color: fg)))));
                  });
              }),
              const SizedBox(height: 8),
              Text(_tapInicio != null ? 'Toque no dia final do período' : 'Toque em dois dias para selecionar o período',
                  style: TextStyle(fontSize: 11, color: cs.onSurface.withOpacity(0.38), fontStyle: FontStyle.italic)),
            ]),
          ),
          const SizedBox(height: 8),
        ],
        Builder(builder: (bCtx) {
          final bCs = Theme.of(bCtx).colorScheme;
          final bDark = Theme.of(bCtx).brightness == Brightness.dark;
          if (dias.isEmpty) {
            return Container(padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: bDark ? const Color(0xFF252525) : Colors.white,
                  borderRadius: BorderRadius.circular(16), border: Border.all(color: bCs.onSurface.withOpacity(0.1), width: 0.5)),
              child: Center(child: Text('Nenhum dia no período selecionado.',
                  style: TextStyle(color: bCs.onSurface.withOpacity(0.38)))));
          }
          final totalGanho = dias.fold<double>(0, (s, d) => s + (d['total'] as num).toDouble());
          final totalKm = dias.fold<double>(0, (s, d) => s + (d['km'] as num? ?? 0).toDouble());
          final totalHoras = dias.fold<double>(0, (s, d) => s + (d['horas'] as num? ?? 0).toDouble());
          final totalViagens = dias.fold<int>(0, (s, d) => s + (d['viagens'] as int? ?? 0));
          final totalAbast = dias.fold<double>(0, (s, d) => s + (d['abastecimento'] as num? ?? 0).toDouble());
          final batidas = dias.where((d) => d['bateu'] == true).length;
          final pct = (batidas / dias.length * 100).round();
          final mediaDia = totalGanho / dias.length;
          final mediaH = totalHoras > 0 ? totalGanho / totalHoras : 0.0;
          final mediaKm = totalKm > 0 ? totalGanho / totalKm : 0.0;
          final mediaVia = totalViagens > 0 ? totalGanho / totalViagens : 0.0;
          final liquido = totalGanho - totalAbast;

          return Column(children: [
            Container(width: double.infinity, padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: bDark ? const Color(0xFF252525) : Colors.white,
                  borderRadius: BorderRadius.circular(16), border: Border.all(color: bCs.onSurface.withOpacity(0.1), width: 0.5)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Total ganho (${dias.length} dias)', style: TextStyle(fontSize: 12, color: bCs.onSurface.withOpacity(0.5))),
                const SizedBox(height: 4),
                Text(_fmt(totalGanho), style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w500, color: Color(0xFF1D9E75))),
                if (totalAbast > 0) ...[
                  const SizedBox(height: 6),
                  Row(children: [
                    Text('abastec.: -${_fmt(totalAbast)}', style: const TextStyle(fontSize: 12, color: Color(0xFF993C1D))),
                    const SizedBox(width: 12),
                    Text('líquido: ${_fmt(liquido)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF185FA5))),
                  ]),
                ],
              ])),
            const SizedBox(height: 8),
            GridView.count(crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 8, mainAxisSpacing: 8, childAspectRatio: 2.2,
              children: [
                _numCard('Dias trabalhados', '${dias.length}', bCs.onSurface, bCs),
                _numCard('Metas batidas', '$batidas de ${dias.length}', const Color(0xFF1D9E75), bCs),
                _numCard('Aproveitamento', '$pct%', pct >= 70 ? const Color(0xFF1D9E75) : const Color(0xFFBA7517), bCs),
                _numCard('Total viagens', '$totalViagens', bCs.onSurface, bCs),
                _numCard('Km rodados', '${totalKm.toStringAsFixed(0)} km', const Color(0xFF185FA5), bCs),
                _numCard('Horas trabalhadas', _fmtH(totalHoras), bCs.onSurface, bCs),
              ]),
            const SizedBox(height: 8),
            Container(padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: bDark ? const Color(0xFF252525) : Colors.white,
                  borderRadius: BorderRadius.circular(16), border: Border.all(color: bCs.onSurface.withOpacity(0.1), width: 0.5)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Médias do período', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: bCs.onSurface.withOpacity(0.6))),
                const SizedBox(height: 12),
                _mediaRow('Ganho por dia', _fmt(mediaDia), bCs),
                _mediaRow('Ganho por viagem', _fmt(mediaVia), bCs),
                if (totalHoras > 0) _mediaRow('Ganho por hora', 'R\$ ${mediaH.toStringAsFixed(2).replaceAll('.', ',')}/h', bCs),
                if (totalKm > 0) _mediaRow('Ganho por km', 'R\$ ${mediaKm.toStringAsFixed(2).replaceAll('.', ',')}/km', bCs),
                if (totalAbast > 0) _mediaRow('Líquido por dia', _fmt(liquido / dias.length), bCs),
                if (totalViagens > 0) _mediaRow('Viagens por dia', (totalViagens / dias.length).toStringAsFixed(1), bCs),
              ])),
          ]);
        }),
      ]),
    );
  }

  Widget _numCard(String label, String val, Color color, ColorScheme cs) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: cs.surfaceContainerHighest, borderRadius: BorderRadius.circular(12)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(fontSize: 10, color: cs.onSurface.withOpacity(0.5))),
      const SizedBox(height: 4),
      Text(val, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: color)),
    ]));

  Widget _mediaRow(String label, String val, ColorScheme cs) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: TextStyle(fontSize: 13, color: cs.onSurface.withOpacity(0.6))),
      Text(val, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: cs.onSurface)),
    ]));
}
