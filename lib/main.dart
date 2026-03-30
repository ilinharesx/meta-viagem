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
    final tabs = ['Hoje', 'Diário', 'Resumo'];
    return Scaffold(
      appBar: AppBar(
        title: const Text('Meta Viagem', style: TextStyle(fontWeight: FontWeight.w500)),
        scrolledUnderElevation: 0,
        actions: [
          ValueListenableBuilder<ThemeMode>(
            valueListenable: themeModeNotifier,
            builder: (_, mode, __) => IconButton(
              icon: Icon(mode == ThemeMode.dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
              tooltip: mode == ThemeMode.dark ? 'Modo claro' : 'Modo escuro',
              onPressed: () {
                themeModeNotifier.value = mode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
              },
            ),
          ),
        ],
      ),
      body: Column(children: [
        Builder(builder: (ctx) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;
          return Padding(padding: const EdgeInsets.symmetric(horizontal: 16),
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
                              ? (isDark ? Colors.white : Colors.black87)
                              : (isDark ? Colors.white38 : Colors.black45))),
                  ),
                ),
              ))),
            ));
        }),
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
  // controllers
  final _corridaCtrl = TextEditingController();
  final _metaCtrl = TextEditingController();
  final _totalCtrl = TextEditingController();
  final _nViaCtrl = TextEditingController();
  final _metaTotalCtrl = TextEditingController();
  final _kmCtrl = TextEditingController();
  final _horasCtrl = TextEditingController();
  final _abastCtrl = TextEditingController();
  // data selecionada para modo total
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
      _atual += val; // promo CONTA no saldo
      _viagens.add({
        'val': val,
        'hora': TimeOfDay.now().format(context),
        'promo': isPromo,
      });
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
      context: context,
      initialDate: _dataTotalSelecionada,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      locale: const Locale('pt', 'BR'),
    );
    if (picked != null) setState(() => _dataTotalSelecionada = picked);
  }

  String _fmtData(DateTime d) =>
      '${d.day.toString().padLeft(2,'0')}/${d.month.toString().padLeft(2,'0')}/${d.year}';

  void _encerrarDia() {
    if (_modoTotal) {
      // Modo total: valida campos e monta dia direto
      final total = double.tryParse(_totalCtrl.text.replaceAll(',', '.'));
      final nVia = int.tryParse(_nViaCtrl.text.trim());
      if (total == null || total <= 0) { _showSnack('Informe o total ganho.'); return; }
      if (nVia == null || nVia <= 0) { _showSnack('Informe o número de viagens.'); return; }
      final metaVal = double.tryParse(_metaTotalCtrl.text.replaceAll(',', '.'));
      if (metaVal != null && metaVal > 0) _meta = metaVal;

      final km = double.tryParse(_kmCtrl.text.replaceAll(',', '.')) ?? 0;
      final abastVal = double.tryParse(_abastCtrl.text.replaceAll(',', '.')) ?? 0;
      double horas = _parseHoras(_horasCtrl.text.trim());
      final totalAbast = abastVal;
      final dt = _dataTotalSelecionada;

      showDialog(context: context, builder: (_) => AlertDialog(
        title: const Text('Encerrar o dia?'),
        content: Text('Salvar ${_fmt(total)} em $nVia viagens em ${_fmtData(dt)}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          TextButton(onPressed: () {
            widget.onEncerrarDia({
              'data': _fmtData(dt),
              'dataISO': dt.toIso8601String(),
              'semana': _diaSemana(dt.weekday),
              'total': total,
              'meta': _meta,
              'viagens': nVia,
              'km': km,
              'horas': horas,
              'abastecimento': totalAbast,
              'liquido': total - totalAbast,
              'bateu': total >= _meta,
              'modoTotal': true, // flag: não tem histórico individual
            });
            _totalCtrl.clear(); _nViaCtrl.clear(); _metaTotalCtrl.clear();
            _kmCtrl.clear(); _horasCtrl.clear(); _abastCtrl.clear();
            Navigator.pop(context);
            _showSnack('Dia ${_fmtData(dt)} salvo no Diário!');
          }, child: const Text('Encerrar', style: TextStyle(color: Color(0xFF1D9E75)))),
        ],
      ));
    } else {
      // Modo uma por uma
      if (_viagens.isEmpty) { _showSnack('Adicione pelo menos uma viagem antes de encerrar.'); return; }
      final km = double.tryParse(_kmCtrl.text.replaceAll(',', '.')) ?? 0;
      final abastVal = double.tryParse(_abastCtrl.text.replaceAll(',', '.')) ?? 0;
      double horas = _parseHoras(_horasCtrl.text.trim());
      final totalAbast = _abast + abastVal;
      final now = DateTime.now();

      showDialog(context: context, builder: (_) => AlertDialog(
        title: const Text('Encerrar o dia?'),
        content: Text('Salvar ${_fmt(_atual)} em ${_viagens.length} viagens no Diário?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          TextButton(onPressed: () {
            widget.onEncerrarDia({
              'data': _fmtData(now),
              'dataISO': now.toIso8601String(),
              'semana': _diaSemana(now.weekday),
              'total': _atual,
              'meta': _meta,
              'viagens': _viagens.length,
              'km': km,
              'horas': horas,
              'abastecimento': totalAbast,
              'liquido': _atual - totalAbast,
              'bateu': _atual >= _meta,
              'modoTotal': false,
              'historicoViagens': List.from(_viagens), // salva histórico individual
            });
            _kmCtrl.clear(); _horasCtrl.clear(); _abastCtrl.clear();
            Navigator.pop(context);
            _showSnack('Dia encerrado e salvo no Diário!');
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: Column(children: [
        // Stats topo
        Row(children: [
          _statCard('Saldo bruto', _fmt(_atual), const Color(0xFF1D9E75)),
          const SizedBox(width: 6),
          _statCard('Abastec.', _abast > 0 ? '-${_fmt(_abast)}' : 'R\$ 0,00', const Color(0xFF993C1D)),
          const SizedBox(width: 6),
          _statCard('Líquido', _fmt(_liquido), const Color(0xFF185FA5)),
          const SizedBox(width: 6),
          _statCard('Viagens', '${_viagens.where((v) => v['promo'] != true).length}', Theme.of(context).colorScheme.onSurface),
        ]),
        const SizedBox(height: 12),

        // Barra de progresso
        _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('Meta: ${_fmt(_meta)}', style: const TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6))),
            Text(_falta <= 0 ? 'Meta atingida!' : 'falta ${_fmt(_falta)}',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500,
                    color: _falta <= 0 ? const Color(0xFF1D9E75) : const Color(0xFF993C1D))),
          ]),
          const SizedBox(height: 10),
          ClipRRect(borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(value: _pct, minHeight: 10,
                backgroundColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.1), color: const Color(0xFF1D9E75))),
          const SizedBox(height: 6),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('${(_pct * 100).toStringAsFixed(0)}%',
                style: const TextStyle(fontSize: 11, color: Color(0xFF1D9E75), fontWeight: FontWeight.w500)),
            Text(_fmt(_meta), style: const TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5))),
          ]),
        ])),
        const SizedBox(height: 12),

        // Registrar viagens com toggle
        _card(Column(children: [
          const Align(alignment: Alignment.centerLeft,
            child: Text('Registrar viagens', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)))),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(color: const Color(0xFFEEEEEE), borderRadius: BorderRadius.circular(8)),
            padding: const EdgeInsets.all(3),
            child: Row(children: [
              _toggleBtn('Uma por uma', !_modoTotal, () => setState(() => _modoTotal = false)),
              _toggleBtn('Total do dia', _modoTotal, () => setState(() => _modoTotal = true)),
            ]),
          ),
          const SizedBox(height: 10),

          if (!_modoTotal) ...[
            Row(children: [
              Expanded(child: _inputField(_corridaCtrl, 'Valor da viagem (R\$)', '18.50')),
              const SizedBox(width: 8),
              Expanded(child: _inputField(_metaCtrl, 'Meta (R\$)', '500')),
            ]),
            const SizedBox(height: 8),
            // Checkbox promoção
            GestureDetector(
              onTap: () => setState(() => _ehPromocao = !_ehPromocao),
              child: Row(children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 20, height: 20,
                  decoration: BoxDecoration(
                    color: _ehPromocao ? const Color(0xFFBA7517) : Colors.transparent,
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(
                      color: _ehPromocao ? const Color(0xFFBA7517) : Theme.of(context).colorScheme.onSurface.withOpacity(0.26),
                      width: 1.5,
                    ),
                  ),
                  child: _ehPromocao
                    ? const Icon(Icons.check, size: 14, color: Colors.white)
                    : null,
                ),
                const SizedBox(width: 8),
                Text('É promoção/bônus',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500,
                    color: _ehPromocao ? const Color(0xFFBA7517) : Theme.of(context).colorScheme.onSurface.withOpacity(0.5))),
                const SizedBox(width: 6),
                Text('(não conta no saldo)',
                  style: const TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.38))),
              ]),
            ),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: _btn('+ Viagem', const Color(0xFF1D9E75), Colors.white, _addViagem)),
              const SizedBox(width: 6),
              Expanded(child: _btn('Salvar meta', Colors.white, Theme.of(context).colorScheme.onSurface, _setMeta, border: Theme.of(context).colorScheme.onSurface.withOpacity(0.26))),
              const SizedBox(width: 6),
              Expanded(child: _btn('Zerar', Colors.white, const Color(0xFF993C1D), _zerar, border: const Color(0xFFD85A30))),
            ]),
          ] else ...[
            // Seletor de data para modo total
            GestureDetector(
              onTap: _selecionarData,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F5F0),
                  border: Border.all(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.26), width: 0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(children: [
                  const Icon(Icons.calendar_today_outlined, size: 16, color: Color(0xFF1D9E75)),
                  const SizedBox(width: 8),
                  Text(_fmtData(_dataTotalSelecionada),
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Theme.of(context).colorScheme.onSurface)),
                  const Spacer(),
                  const Text('alterar', style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.38))),
                ]),
              ),
            ),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: _inputField(_totalCtrl, 'Total ganho (R\$)', 'ex: 280.00')),
              const SizedBox(width: 8),
              Expanded(child: _inputField(_nViaCtrl, 'Nº de viagens', 'ex: 15')),
            ]),
            const SizedBox(height: 8),
            _inputField(_metaTotalCtrl, 'Meta do dia (R\$)', '500'),
            const SizedBox(height: 6),
            const Text('os dados do expediente serão preenchidos na seção abaixo',
                style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.38))),
          ],
        ])),
        const SizedBox(height: 12),

        // Encerrar o dia
        _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Encerrar o dia', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6))),
          const SizedBox(height: 10),
          Container(height: 0.5, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.12)),
          const SizedBox(height: 10),
          const Text('Dados do expediente', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5))),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: _inputField(_kmCtrl, 'Km rodados', 'ex: 187')),
            const SizedBox(width: 8),
            Expanded(child: _inputField(_horasCtrl, 'Horas trabalhadas', 'ex: 8h30')),
          ]),
          const SizedBox(height: 8),
          SizedBox(width: MediaQuery.of(context).size.width / 2 - 20,
            child: _inputField(_abastCtrl, 'Abastecimento (R\$)', 'ex: 80.00')),
          const SizedBox(height: 12),
          Container(height: 0.5, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.12)),
          const SizedBox(height: 12),
          Builder(builder: (ctx) {
            final dark = Theme.of(ctx).brightness == Brightness.dark;
            return GestureDetector(
              onTap: _encerrarDia,
              child: Container(
                width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 13),
                decoration: BoxDecoration(
                  color: dark ? Colors.white : const Color(0xFF1D9E75),
                  borderRadius: BorderRadius.circular(10)),
                child: Center(child: Text('+ Encerrar dia e salvar',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500,
                        color: dark ? Colors.black : Colors.white))),
              ),
            );
          }),
          const SizedBox(height: 6),
          const Center(child: Text('salva no Diário e zera o contador de hoje',
              style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.38)))),
        ])),
        const SizedBox(height: 12),

        // Histórico (só no modo uma por uma)
        if (!_modoTotal && _viagens.isNotEmpty)
          _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Builder(builder: (_) {
              final normais = _viagens.where((v) => v['promo'] != true).length;
              final promos = _viagens.where((v) => v['promo'] == true).length;
              return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('Viagens de hoje', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6))),
                Text('$normais viagens${promos > 0 ? ' · $promos promo' : ''} · ${_fmt(_media)}/viag.',
                    style: const TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.38))),
              ]);
            }),
            const SizedBox(height: 10),
            ..._viagens.reversed.take(30).toList().asMap().entries.map((e) {
              final orig = _viagens.length - 1 - e.key;
              final v = e.value;
              final isPromo = v['promo'] == true;
              // numero sequencial só de viagens normais
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
                  Text(v['hora'] ?? '', style: const TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.38))),
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

  Widget _toggleBtn(String label, bool active, VoidCallback onTap) => Expanded(
    child: GestureDetector(onTap: onTap,
      child: AnimatedContainer(duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 7),
        decoration: BoxDecoration(color: active ? Colors.white : Colors.transparent, borderRadius: BorderRadius.circular(6)),
        child: Text(label, textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500,
                color: active ? Theme.of(ctx).colorScheme.onSurface : Theme.of(ctx).colorScheme.onSurface.withOpacity(0.5))))));

  Widget _card(Widget child) => Builder(builder: (ctx) {
    final isDark = Theme.of(ctx).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF252525) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? const Color(0x22FFFFFF) : Colors.black12, width: 0.5)),
      child: child);
  });

  Widget _statCard(String label, String value, Color color) => Expanded(
    child: Builder(builder: (ctx) {
      final isDark = Theme.of(ctx).brightness == Brightness.dark;
      return Container(padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFEEEEEE),
          borderRadius: BorderRadius.circular(10)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(fontSize: 9, color: Theme.of(ctx).colorScheme.onSurface.withOpacity(0.5))),
          const SizedBox(height: 2),
          Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: color)),
        ]));
    }));

  Widget _inputField(TextEditingController ctrl, String label, String hint) =>
    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6))),
      const SizedBox(height: 4),
      TextField(controller: ctrl,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(hintText: hint, hintStyle: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.38)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3), width: 0.5)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3), width: 0.5)))),
    ]);

  Widget _btn(String label, Color bg, Color fg, VoidCallback onTap, {Color border = Colors.transparent}) =>
    Builder(builder: (ctx) {
      final isDark = Theme.of(ctx).brightness == Brightness.dark;
      // green button becomes white in dark, outline buttons adapt
      Color effectiveBg = bg;
      Color effectiveFg = fg;
      Color effectiveBorder = border;
      if (bg == const Color(0xFF1D9E75)) {
        effectiveBg = isDark ? Colors.white : const Color(0xFF1D9E75);
        effectiveFg = isDark ? Colors.black : Colors.white;
      } else if (bg == Colors.white) {
        effectiveBg = isDark ? const Color(0xFF2A2A2A) : Colors.white;
        effectiveFg = isDark ? Colors.white70 : fg;
        effectiveBorder = isDark ? Colors.white24 : border;
      }
      return GestureDetector(onTap: onTap,
        child: Container(padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(color: effectiveBg, borderRadius: BorderRadius.circular(8),
              border: Border.all(color: effectiveBorder, width: 0.5)),
          child: Center(child: Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: effectiveFg)))));
    });
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
      context: context,
      initialDate: _filtroData ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      locale: const Locale('pt', 'BR'),
    );
    if (picked != null) setState(() => _filtroData = picked);
  }

  @override
  Widget build(BuildContext context) {
    final dias = _diasFiltrados;

    if (widget.dias.isEmpty) return const Center(child: Text('Nenhum dia registrado ainda.\nEncerre o primeiro dia na aba Hoje!',
        textAlign: TextAlign.center, style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.38), fontSize: 14)));

    final batidas = widget.dias.where((d) => d['bateu'] == true).length;
    final pct = (batidas / widget.dias.length * 100).round();
    final kmTotal = widget.dias.fold<double>(0, (s, d) => s + (d['km'] as num? ?? 0).toDouble());

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: Column(children: [
        Row(children: [
          _mini('dias', '${widget.dias.length}', Theme.of(context).colorScheme.onSurface),
          const SizedBox(width: 6),
          _mini('metas', '$batidas/${widget.dias.length}', const Color(0xFF1D9E75)),
          const SizedBox(width: 6),
          _mini('aproveit.', '$pct%', const Color(0xFFBA7517)),
          const SizedBox(width: 6),
          _mini('km total', '${kmTotal.toStringAsFixed(0)}', const Color(0xFF185FA5)),
        ]),
        const SizedBox(height: 10),
        // Filtro de data
        Row(children: [
          Expanded(child: GestureDetector(
            onTap: _selecionarFiltro,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: _filtroData != null ? const Color(0xFFE1F5EE) : Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _filtroData != null ? const Color(0xFF5DCAA5) : Colors.black12, width: 0.5),
              ),
              child: Row(children: [
                Icon(Icons.calendar_today_outlined, size: 15,
                    color: _filtroData != null ? const Color(0xFF085041) : Theme.of(ctx).colorScheme.onSurface.withOpacity(0.5)),
                const SizedBox(width: 8),
                Text(_filtroData != null ? _fmtDate(_filtroData!) : 'Filtrar por data',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500,
                        color: _filtroData != null ? const Color(0xFF085041) : Theme.of(ctx).colorScheme.onSurface.withOpacity(0.6))),
              ]),
            ),
          )),
          if (_filtroData != null) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => setState(() => _filtroData = null),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.close, size: 16, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5)),
              ),
            ),
          ],
        ]),
        const SizedBox(height: 10),
        if (dias.isEmpty)
          Container(padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.12), width: 0.5)),
            child: Center(child: Text('Nenhum registro em ${_fmtDate(_filtroData!)}.',
                style: const TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.38)))))
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
              child: Builder(builder: (ctx) {
              final isDark = Theme.of(ctx).brightness == Brightness.dark;
              return Container(padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF252525) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: temHistorico ? const Color(0xFF9FE1CB) : (isDark ? Colors.white12 : Colors.black12),
                    width: temHistorico ? 1.0 : 0.5,
                  )),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Text(d['data'] ?? '', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                        if (temHistorico) ...[
                          const SizedBox(width: 6),
                          const Icon(Icons.expand_more, size: 16, color: Color(0xFF1D9E75)),
                        ],
                      ]),
                      Text(d['semana'] ?? '', style: const TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.38))),
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
                          decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(6)),
                          child: const Icon(Icons.close, size: 13, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.38)))),
                    ]),
                  ]),
                  const SizedBox(height: 8),
                  Container(height: 0.5, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.12)),
                  const SizedBox(height: 8),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    const Text('total bruto', style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5))),
                    Text(_fmt(total), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500,
                        color: bateu ? const Color(0xFF1D9E75) : const Color(0xFF993C1D))),
                  ]),
                  if (abast > 0) ...[
                    const SizedBox(height: 3),
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      const Text('abastecimento', style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5))),
                      Text('-${_fmt(abast)}', style: const TextStyle(fontSize: 12, color: Color(0xFF993C1D))),
                    ]),
                    const SizedBox(height: 3),
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      const Text('líquido', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6))),
                      Text(_fmt(liquido), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF185FA5))),
                    ]),
                  ],
                  const SizedBox(height: 3),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    const Text('meta do dia', style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5))),
                    Text(_fmt(meta), style: const TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface)),
                  ]),
                  const SizedBox(height: 3),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    const Text('viagens · km · horas', style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5))),
                    Text('$viagens${km > 0 ? ' · ${km.toStringAsFixed(0)}km' : ''}${horas > 0 ? ' · ${_fmtH(horas)}' : ''}',
                        style: const TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface)),
                  ]),
                  if (km > 0 || horas > 0) ...[
                    const SizedBox(height: 10),
                    Row(children: [
                      if (horas > 0) Expanded(child: _mediaCard('ganho por hora', 'R\$ ${ganhoH.toStringAsFixed(2).replaceAll('.', ',')}/h')),
                      if (horas > 0 && km > 0) const SizedBox(width: 8),
                      if (km > 0) Expanded(child: _mediaCard('ganho por km', 'R\$ ${ganhoKm.toStringAsFixed(2).replaceAll('.', ',')}/km')),
                    ]),
                  ],
                  const SizedBox(height: 10),
                  ClipRRect(borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(value: pctDia, minHeight: 6,
                      backgroundColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.1),
                      color: bateu ? const Color(0xFF1D9E75) : const Color(0xFF993C1D))),
                  const SizedBox(height: 4),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text('${(pctDia * 100).toStringAsFixed(0)}%',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500,
                            color: bateu ? const Color(0xFF1D9E75) : const Color(0xFF993C1D))),
                    Text(_fmt(meta), style: const TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.38))),
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
                ]));
            }),
            ));
        }),
      ]),
    );
  }

  void _abrirHistorico(BuildContext context, Map<String, dynamic> d, List historico) {
    final fmt = (double v) => 'R\$ ${v.toStringAsFixed(2).replaceAll('.', ',')}';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => GestureDetector(
        onTap: () => Navigator.pop(sheetCtx),
        behavior: HitTestBehavior.opaque,
        child: DraggableScrollableSheet(
          initialChildSize: 0.6,
          maxChildSize: 0.9,
          minChildSize: 0.3,
          builder: (_, ctrl) => GestureDetector(
            onTap: () {},
            child: Container(
              decoration: const BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(children: [
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  width: 40, height: 4,
                  decoration: BoxDecoration(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.12), borderRadius: BorderRadius.circular(99)),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${d['data']} · ${d['semana']}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                      Text('${historico.length} viagens · ${fmt((d['total'] as num).toDouble())}',
                          style: const TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5))),
                    ])),
                  ]),
                ),
                Container(height: 0.5, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.12)),
                Expanded(child: ListView.builder(
                  controller: ctrl,
                  padding: const EdgeInsets.all(16),
                  itemCount: historico.length,
                  itemBuilder: (_, i) {
                    final v = historico[i] as Map;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(color: const Color(0xFF9FE1CB), borderRadius: BorderRadius.circular(99)),
                          child: Text('#${i + 1}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Color(0xFF085041))),
                        ),
                        const SizedBox(width: 10),
                        Text(v['hora']?.toString() ?? '', style: const TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5))),
                        const Spacer(),
                        Text('+${fmt((v['val'] as num).toDouble())}',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF1D9E75))),
                      ]),
                    );
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

  Widget _mini(String label, String val, Color color) => Expanded(
    child: Builder(builder: (ctx) {
      final isDark = Theme.of(ctx).brightness == Brightness.dark;
      return Container(padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFEEEEEA),
          borderRadius: BorderRadius.circular(10)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(fontSize: 9, color: Theme.of(ctx).colorScheme.onSurface.withOpacity(0.5))),
          const SizedBox(height: 2),
          Text(val, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: color)),
        ]));
    }));

  Widget _mediaCard(String label, String val) => Builder(builder: (ctx) {
    final isDark = Theme.of(ctx).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF5F5F0),
        borderRadius: BorderRadius.circular(8)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(fontSize: 9, color: Theme.of(ctx).colorScheme.onSurface.withOpacity(0.5))),
        const SizedBox(height: 2),
        Text(val, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF1D9E75))),
      ]));
  });
}

// ─── ABA RESUMO ───────────────────────────────────────────────────────────────

class ResumoTab extends StatefulWidget {
  final List<Map<String, dynamic>> dias;
  const ResumoTab({super.key, required this.dias});
  @override State<ResumoTab> createState() => _ResumoTabState();
}

class _ResumoTabState extends State<ResumoTab> {
  DateTime? _inicio;
  DateTime? _fim;
  DateTime _calMes = DateTime.now();
  bool _showCal = false;
  String _quickSel = '30';
  // para seleção de range no calendário
  DateTime? _tapInicio;

  @override
  void initState() { super.initState(); _aplicarQuick('30'); }

  void _aplicarQuick(String q) {
    final now = DateTime.now();
    setState(() {
      _quickSel = q;
      _tapInicio = null;
      _fim = now;
      if (q == 'hoje') { _inicio = DateTime(now.year, now.month, now.day); }
      else if (q == 'mes') { _inicio = DateTime(now.year, now.month, 1); }
      else if (q == 'ano') { _inicio = DateTime(now.year, 1, 1); }
      else if (q == 'tudo') { _inicio = DateTime(2020, 1, 1); }
      else { final days = int.tryParse(q) ?? 30; _inicio = now.subtract(Duration(days: days)); }
    });
  }

  void _tapDia(DateTime dia) {
    setState(() {
      if (_tapInicio == null) {
        // Primeiro toque: define início
        _tapInicio = DateTime(dia.year, dia.month, dia.day);
        _inicio = _tapInicio;
        _fim = _tapInicio;
        _quickSel = '';
      } else {
        // Segundo toque: define fim (ou redefine se clicar no mesmo dia)
        final fim = DateTime(dia.year, dia.month, dia.day);
        if (fim.isBefore(_tapInicio!)) {
          // Clicou antes do início: inverte
          _inicio = fim;
          _fim = _tapInicio;
        } else {
          _inicio = _tapInicio;
          _fim = fim;
        }
        _tapInicio = null; // reset para próxima seleção
        _quickSel = '';
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
        else {
          final parts = (d['data'] as String).split('/');
          dt = DateTime(int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
        }
        return !dt.isBefore(_inicio!) && !dt.isAfter(fimDia);
      } catch (_) { return true; }
    }).toList();
  }

  String _fmt(double v) => 'R\$ ${v.toStringAsFixed(2).replaceAll('.', ',')}';
  String _fmtH(double h) { final hh = h.floor(); final mm = ((h-hh)*60).round(); return mm > 0 ? '${hh}h${mm.toString().padLeft(2,'0')}' : '${hh}h'; }
  String _fmtDate(DateTime d) => '${d.day.toString().padLeft(2,'0')}/${d.month.toString().padLeft(2,'0')}/${d.year}';

  bool _isStart(DateTime d) => _inicio != null && d.year == _inicio!.year && d.month == _inicio!.month && d.day == _inicio!.day;
  bool _isEnd(DateTime d) => _fim != null && d.year == _fim!.year && d.month == _fim!.month && d.day == _fim!.day;
  bool _isInRange(DateTime d) {
    if (_inicio == null || _fim == null) return false;
    return !d.isBefore(_inicio!) && !d.isAfter(_fim!);
  }
  bool _isToday(DateTime d) { final n = DateTime.now(); return d.year == n.year && d.month == n.month && d.day == n.day; }

  @override
  Widget build(BuildContext context) {
    final dias = _diasFiltrados;
    final meses = ['Janeiro','Fevereiro','Março','Abril','Maio','Junho','Julho','Agosto','Setembro','Outubro','Novembro','Dezembro'];

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: Column(children: [
        // Botão filtro
        Builder(builder: (ctx) {
          final isDarkR = Theme.of(ctx).brightness == Brightness.dark;
          return GestureDetector(
          onTap: () => setState(() => _showCal = !_showCal),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: _showCal ? const Color(0xFFE1F5EE) : (isDarkR ? const Color(0xFF252525) : Colors.white),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _showCal ? const Color(0xFF5DCAA5) : (isDarkR ? Colors.white12 : Colors.black12), width: 0.5),
            ),
            child: Row(children: [
              Icon(Icons.calendar_month_outlined, size: 16, color: _showCal ? const Color(0xFF085041) : Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
              const SizedBox(width: 8),
              Expanded(child: Text(
                _inicio != null && _fim != null ? '${_fmtDate(_inicio!)}  →  ${_fmtDate(_fim!)}' : 'Selecionar período',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500,
                    color: _showCal ? const Color(0xFF085041) : Theme.of(context).colorScheme.onSurface),
              )),
              Icon(_showCal ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, size: 18, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.38)),
            ]),
          ),
          );
        }),
        const SizedBox(height: 8),

        // Chips de atalho — sem 60 e 90, com "Todo período" e "Anual"
        SingleChildScrollView(scrollDirection: Axis.horizontal,
          child: Row(children: [
            for (final q in [
              ('hoje', 'Hoje'),
              ('7', '7 dias'),
              ('30', '30 dias'),
              ('mes', 'Este mês'),
              ('ano', 'Este ano'),
              ('tudo', 'Todo período'),
            ])
              Padding(padding: const EdgeInsets.only(right: 6),
                child: GestureDetector(onTap: () => _aplicarQuick(q.$1),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _quickSel == q.$1 ? const Color(0xFF1D9E75) : const Color(0xFFEEEEEE),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(q.$2, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500,
                        color: _quickSel == q.$1 ? Colors.white : Theme.of(context).colorScheme.onSurface.withOpacity(0.6))),
                  ))),
          ])),
        const SizedBox(height: 8),

        // Calendário expansível
        if (_showCal) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.12), width: 0.5)),
            child: Column(children: [
              // Header mês
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                GestureDetector(
                  onTap: () => setState(() => _calMes = DateTime(_calMes.year, _calMes.month - 1)),
                  child: const Padding(padding: EdgeInsets.all(6), child: Icon(Icons.chevron_left, size: 22, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)))),
                Text('${meses[_calMes.month - 1]} ${_calMes.year}',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                GestureDetector(
                  onTap: () => setState(() => _calMes = DateTime(_calMes.year, _calMes.month + 1)),
                  child: const Padding(padding: EdgeInsets.all(6), child: Icon(Icons.chevron_right, size: 22, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)))),
              ]),
              const SizedBox(height: 10),
              // Nomes dos dias
              Row(children: ['D','S','T','Q','Q','S','S'].map((d) => Expanded(
                child: Center(child: Text(d, style: const TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.38), fontWeight: FontWeight.w500))))).toList()),
              const SizedBox(height: 4),
              // Grid
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
                    final isPendente = _tapInicio != null && dia == _tapInicio;

                    Color bg = Colors.transparent;
                    Color fg = Colors.black87;
                    BorderRadius br = BorderRadius.circular(6);

                    if (start) { bg = const Color(0xFF1D9E75); fg = Colors.white; br = BorderRadius.circular(99); }
                    else if (end) { bg = const Color(0xFF1D9E75); fg = Colors.white; br = BorderRadius.circular(99); }
                    else if (inRange) { bg = const Color(0xFFE1F5EE); fg = const Color(0xFF085041); br = BorderRadius.zero; }
                    else if (today) { bg = const Color(0xFFB5D4F4); fg = const Color(0xFF0C447C); br = BorderRadius.circular(99); }

                    return GestureDetector(
                      onTap: () => _tapDia(dia),
                      child: Container(
                        decoration: BoxDecoration(color: bg, borderRadius: br),
                        child: Center(child: Text('${dia.day}',
                            style: TextStyle(fontSize: 11,
                                fontWeight: (start || end || isPendente) ? FontWeight.w700 : FontWeight.normal,
                                color: fg)))));
                  });
              }),
              const SizedBox(height: 8),
              if (_tapInicio != null)
                Text('Toque no dia final do período',
                    style: const TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.38), fontStyle: FontStyle.italic))
              else
                Text('Toque em dois dias para selecionar o período',
                    style: const TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.38), fontStyle: FontStyle.italic)),
            ]),
          ),
          const SizedBox(height: 8),
        ],

        // Resultados
        Builder(builder: (_) {
          if (dias.isEmpty) {
            return Container(padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.12), width: 0.5)),
              child: const Center(child: Text('Nenhum dia no período selecionado.',
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.38)))));
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
            Builder(builder: (ctx) {
              final isDark = Theme.of(ctx).brightness == Brightness.dark;
              return Container(width: double.infinity, padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF252525) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: isDark ? Colors.white12 : Colors.black12, width: 0.5)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Total ganho (${dias.length} dias)', style: const TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5))),
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
              ]));
            }),
            const SizedBox(height: 8),
            GridView.count(crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 8, mainAxisSpacing: 8, childAspectRatio: 2.2,
              children: [
                _numCard('Dias trabalhados', '${dias.length}', Theme.of(context).colorScheme.onSurface),
                _numCard('Metas batidas', '$batidas de ${dias.length}', const Color(0xFF1D9E75)),
                _numCard('Aproveitamento', '$pct%', pct >= 70 ? const Color(0xFF1D9E75) : const Color(0xFFBA7517)),
                _numCard('Total viagens', '$totalViagens', Theme.of(context).colorScheme.onSurface),
                _numCard('Km rodados', '${totalKm.toStringAsFixed(0)} km', const Color(0xFF185FA5)),
                _numCard('Horas trabalhadas', _fmtH(totalHoras), Theme.of(context).colorScheme.onSurface),
              ]),
            const SizedBox(height: 8),
            Builder(builder: (ctx) {
              final isDark = Theme.of(ctx).brightness == Brightness.dark;
              return Container(padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF252525) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: isDark ? Colors.white12 : Colors.black12, width: 0.5)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Médias do período', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6))),
                const SizedBox(height: 12),
                _mediaRow('Ganho por dia', _fmt(mediaDia)),
                _mediaRow('Ganho por viagem', _fmt(mediaVia)),
                if (totalHoras > 0) _mediaRow('Ganho por hora', 'R\$ ${mediaH.toStringAsFixed(2).replaceAll('.', ',')}/h'),
                if (totalKm > 0) _mediaRow('Ganho por km', 'R\$ ${mediaKm.toStringAsFixed(2).replaceAll('.', ',')}/km'),
                if (totalAbast > 0) _mediaRow('Líquido por dia', _fmt(liquido / dias.length)),
                if (totalViagens > 0) _mediaRow('Viagens por dia', (totalViagens / dias.length).toStringAsFixed(1)),
              ]));
            }),
          ]);
        }),
      ]),
    );
  }

  Widget _numCard(String label, String val, Color color) => Builder(builder: (ctx) {
    final isDark = Theme.of(ctx).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFEEEEEA),
        borderRadius: BorderRadius.circular(12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(fontSize: 10, color: Theme.of(ctx).colorScheme.onSurface.withOpacity(0.5))),
        const SizedBox(height: 4),
        Text(val, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: color)),
      ]));
  });

  Widget _mediaRow(String label, String val) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: const TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6))),
      Text(val, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Theme.of(context).colorScheme.onSurface)),
    ]));
}
