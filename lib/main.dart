import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MetaViagemApp());
}

final ValueNotifier<bool> darkModeNotifier = ValueNotifier(true);

// ─── DESIGN TOKENS ────────────────────────────────────────────────────────────
class T {
  // Dark green theme
  static const bgDark       = Color(0xFF0A1A0F);
  static const bgCard       = Color(0xFF122418);
  static const bgCardLight  = Color(0xFF1A3020);
  static const bgInput      = Color(0xFF0F1E14);
  static const accent       = Color(0xFF00E676);
  static const accentDim    = Color(0xFF1D9E75);
  static const red          = Color(0xFFFF5252);
  static const amber        = Color(0xFFFFB300);
  static const blue         = Color(0xFF40C4FF);
  static const border       = Color(0xFF1E3A28);
  static const borderBright = Color(0xFF2E5A38);
  static const textPrimary  = Color(0xFFE8F5E9);
  static const textSecondary= Color(0xFF81C784);
  static const textMuted    = Color(0xFF4CAF50);
  static const textDim      = Color(0xFF2E7D32);

  // Light theme
  static const lBg          = Color(0xFFF5F5F0);
  static const lCard        = Color(0xFFFFFFFF);
  static const lCardAlt     = Color(0xFFEEEEEA);
  static const lBorder      = Color(0xFFE0E0E0);
  static const lText        = Color(0xFF1A1A1A);
  static const lTextMuted   = Color(0xFF666666);
  static const lTextDim     = Color(0xFF999999);
  static const lAccent      = Color(0xFF1D9E75);
}

class MetaViagemApp extends StatelessWidget {
  const MetaViagemApp({super.key});
  @override
  Widget build(BuildContext context) => ValueListenableBuilder<bool>(
    valueListenable: darkModeNotifier,
    builder: (_, isDark, __) => MaterialApp(
      title: 'Meta Viagem',
      debugShowCheckedModeBanner: false,
      themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
      theme: ThemeData(colorSchemeSeed: const Color(0xFF1D9E75), useMaterial3: true, brightness: Brightness.light),
      darkTheme: ThemeData(colorSchemeSeed: const Color(0xFF00E676), useMaterial3: true, brightness: Brightness.dark),
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      supportedLocales: const [Locale('pt', 'BR'), Locale('en')],
      home: const RootPage(),
    ),
  );
}

// ─── HELPERS ──────────────────────────────────────────────────────────────────
String fmtMoney(double v) => 'R\$ ${v.toStringAsFixed(2).replaceAll('.', ',')}';
String fmtH(double h) { final hh = h.floor(); final mm = ((h-hh)*60).round(); return mm > 0 ? '${hh}h${mm.toString().padLeft(2,'0')}' : '${hh}h'; }
String fmtDate(DateTime d) => '${d.day.toString().padLeft(2,'0')}/${d.month.toString().padLeft(2,'0')}/${d.year}';
String diaSemana(int w) => ['Segunda','Terça','Quarta','Quinta','Sexta','Sábado','Domingo'][w-1];

// ─── SHARED WIDGETS ───────────────────────────────────────────────────────────
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  const AppCard({super.key, required this.child, this.padding});
  @override
  Widget build(BuildContext context) {
    final dark = darkModeNotifier.value;
    return Container(
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: dark ? T.bgCard : T.lCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: dark ? T.border : T.lBorder, width: 1),
      ),
      child: child,
    );
  }
}

class StatPill extends StatelessWidget {
  final String label, value;
  final Color valueColor;
  const StatPill({super.key, required this.label, required this.value, required this.valueColor});
  @override
  Widget build(BuildContext context) {
    final dark = darkModeNotifier.value;
    return Expanded(child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: dark ? T.bgCardLight : T.lCardAlt,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: dark ? T.border : T.lBorder, width: 1),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, letterSpacing: 0.8,
            color: dark ? T.textSecondary : T.lTextMuted)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: valueColor)),
      ]),
    ));
  }
}

class AppInput extends StatelessWidget {
  final TextEditingController ctrl;
  final String label, hint;
  const AppInput({super.key, required this.ctrl, required this.label, required this.hint});
  @override
  Widget build(BuildContext context) {
    final dark = darkModeNotifier.value;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, letterSpacing: 0.8,
          color: dark ? T.textSecondary : T.lTextMuted)),
      const SizedBox(height: 6),
      TextField(
        controller: ctrl,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        style: TextStyle(color: dark ? T.textPrimary : T.lText, fontSize: 14, fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: dark ? T.textDim : T.lTextDim, fontSize: 13),
          filled: true,
          fillColor: dark ? T.bgInput : const Color(0xFFF5F5F0),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: dark ? T.border : T.lBorder)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: dark ? T.border : T.lBorder)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: dark ? T.accent : T.lAccent, width: 1.5)),
        ),
      ),
    ]);
  }
}

class PrimaryBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool isDanger;
  final bool isSecondary;
  const PrimaryBtn({super.key, required this.label, required this.onTap, this.isDanger = false, this.isSecondary = false});
  @override
  Widget build(BuildContext context) {
    final dark = darkModeNotifier.value;
    Color bg, fg;
    if (isDanger) { bg = dark ? const Color(0xFF3A1010) : const Color(0xFFFFEBEE); fg = T.red; }
    else if (isSecondary) { bg = dark ? T.bgCardLight : T.lCardAlt; fg = dark ? T.textPrimary : T.lText; }
    else { bg = dark ? T.accent : T.lAccent; fg = dark ? Colors.black : Colors.white; }
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          border: isDanger ? Border.all(color: T.red.withOpacity(0.4), width: 1) : null,
        ),
        child: Center(child: Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: fg))),
      ),
    );
  }
}

// ─── ROOT ─────────────────────────────────────────────────────────────────────
class RootPage extends StatefulWidget {
  const RootPage({super.key});
  @override State<RootPage> createState() => _RootPageState();
}

class _RootPageState extends State<RootPage> {
  int _tab = 0;
  late PageController _pageCtrl;
  double _atual = 0, _meta = 500, _abast = 0;
  List<Map<String, dynamic>> _viagens = [];
  List<Map<String, dynamic>> _dias = [];

  @override
  void initState() {
    super.initState();
    _pageCtrl = PageController();
    _load();
    darkModeNotifier.addListener(() => setState(() {}));
  }

  @override
  void dispose() { _pageCtrl.dispose(); super.dispose(); }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    setState(() {
      _atual = p.getDouble('atual') ?? 0;
      _meta = p.getDouble('meta') ?? 500;
      _abast = p.getDouble('abast') ?? 0;
      final rv = p.getString('viagens'); if (rv != null) _viagens = List<Map<String, dynamic>>.from(jsonDecode(rv));
      final rd = p.getString('dias'); if (rd != null) _dias = List<Map<String, dynamic>>.from(jsonDecode(rd));
      final dm = p.getBool('darkMode'); if (dm != null) darkModeNotifier.value = dm;
    });
  }

  Future<void> _save() async {
    final p = await SharedPreferences.getInstance();
    await p.setDouble('atual', _atual);
    await p.setDouble('meta', _meta);
    await p.setDouble('abast', _abast);
    await p.setString('viagens', jsonEncode(_viagens));
    await p.setString('dias', jsonEncode(_dias));
  }

  void _onHojeChanged(double atual, double meta, double abast, List<Map<String, dynamic>> viagens) {
    setState(() { _atual = atual; _meta = meta; _abast = abast; _viagens = viagens; });
    _save();
  }

  void _onEncerrarDia(Map<String, dynamic> dia) {
    setState(() { _dias.insert(0, dia); _atual = 0; _viagens = []; _abast = 0; });
    _save();
  }

  @override
  Widget build(BuildContext context) {
    final dark = darkModeNotifier.value;
    final tabs = ['Hoje', 'Diário', 'Resumo'];
    return Scaffold(
      backgroundColor: dark ? T.bgDark : T.lBg,
      appBar: AppBar(
        backgroundColor: dark ? T.bgDark : T.lBg,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: RichText(text: TextSpan(
          children: [
            TextSpan(text: 'Meta ', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w300,
                color: dark ? T.textPrimary : T.lText)),
            TextSpan(text: 'Viagem', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700,
                color: dark ? T.accent : T.lAccent)),
          ],
        )),
        actions: [
          GestureDetector(
            onTap: () async {
              darkModeNotifier.value = !dark;
              final p = await SharedPreferences.getInstance();
              await p.setBool('darkMode', darkModeNotifier.value);
            },
            child: Container(
              margin: const EdgeInsets.only(right: 16),
              width: 42, height: 42,
              decoration: BoxDecoration(
                color: dark ? T.bgCard : T.lCardAlt,
                shape: BoxShape.circle,
                border: Border.all(color: dark ? T.border : T.lBorder),
              ),
              child: Center(child: Text(dark ? '☀️' : '🌙', style: const TextStyle(fontSize: 18))),
            ),
          ),
        ],
      ),
      body: Column(children: [
        Padding(padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            decoration: BoxDecoration(
              color: dark ? T.bgCard : T.lCardAlt,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: dark ? T.border : T.lBorder)),
            padding: const EdgeInsets.all(4),
            child: Row(children: List.generate(3, (i) => Expanded(
              child: GestureDetector(
                onTap: () {
                  setState(() => _tab = i);
                  _pageCtrl.animateToPage(i, duration: const Duration(milliseconds: 250), curve: Curves.easeInOut);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: _tab == i ? (dark ? T.accent : T.lAccent) : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(tabs[i], textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                          color: _tab == i ? (dark ? Colors.black : Colors.white)
                              : (dark ? T.textSecondary : T.lTextMuted))),
                ),
              ),
            ))),
          )),
        const SizedBox(height: 14),
        Expanded(child: PageView(
          controller: _pageCtrl,
          onPageChanged: (i) => setState(() => _tab = i),
          children: [
            HojeTab(atual: _atual, meta: _meta, abast: _abast, viagens: _viagens,
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
  final double atual, meta, abast;
  final List<Map<String, dynamic>> viagens;
  final Function(double, double, double, List<Map<String, dynamic>>) onChanged;
  final Function(Map<String, dynamic>) onEncerrarDia;
  const HojeTab({super.key, required this.atual, required this.meta, required this.abast,
    required this.viagens, required this.onChanged, required this.onEncerrarDia});
  @override State<HojeTab> createState() => _HojeTabState();
}

class _HojeTabState extends State<HojeTab> {
  late double _atual, _meta, _abast;
  late List<Map<String, dynamic>> _viagens;
  bool _modoTotal = false, _ehPromo = false;
  final _vCtrl = TextEditingController();
  final _mCtrl = TextEditingController();
  final _totalCtrl = TextEditingController();
  final _nViaCtrl = TextEditingController();
  final _mTotalCtrl = TextEditingController();
  final _kmCtrl = TextEditingController();
  final _hCtrl = TextEditingController();
  final _abastCtrl = TextEditingController();
  DateTime _dataTotal = DateTime.now();

  @override
  void initState() { super.initState(); _sync(); }
  void _sync() { _atual = widget.atual; _meta = widget.meta; _abast = widget.abast; _viagens = List.from(widget.viagens); }
  @override
  void didUpdateWidget(HojeTab old) {
    super.didUpdateWidget(old);
    if (old.atual != widget.atual || old.meta != widget.meta || old.abast != widget.abast || old.viagens != widget.viagens) {
      setState(_sync);
    }
  }

  void _notify() => widget.onChanged(_atual, _meta, _abast, _viagens);
  double get _pct => _meta > 0 ? (_atual / _meta).clamp(0, 1) : 0;
  double get _falta => (_meta - _atual).clamp(0, double.infinity);
  double get _liquido => (_atual - _abast).clamp(0, double.infinity);
  int get _countViagens => _viagens.where((v) => v['promo'] != true).length;
  double get _media { final n = _viagens.where((v) => v['promo'] != true).toList(); return n.isEmpty ? 0 : _atual / n.length; }

  void _addViagem() {
    final val = double.tryParse(_vCtrl.text.replaceAll(',', '.'));
    if (val == null || val <= 0) return;
    setState(() { _atual += val; _viagens.add({'val': val, 'hora': TimeOfDay.now().format(context), 'promo': _ehPromo}); _ehPromo = false; });
    _vCtrl.clear(); _notify();
  }

  void _removeViagem(int idx) {
    final val = (_viagens[idx]['val'] as num).toDouble();
    _confirm('Excluir viagem?', 'Viagem de ${fmtMoney(val)} será removida.', () {
      setState(() { _atual = (_atual - val).clamp(0, double.infinity); _viagens.removeAt(idx); });
      _notify();
    });
  }

  void _setMeta() {
    final val = double.tryParse(_mCtrl.text.replaceAll(',', '.'));
    if (val == null || val <= 0) return;
    setState(() => _meta = val); _mCtrl.clear(); _notify();
    _snack('Meta atualizada para ${fmtMoney(val)}');
  }

  void _zerar() => _confirm('Zerar tudo?', 'Apaga saldo, viagens e abastecimento de hoje.', () {
    setState(() { _atual = 0; _viagens = []; _abast = 0; }); _notify();
  });

  void _encerrarDia() {
    final km = double.tryParse(_kmCtrl.text.replaceAll(',', '.')) ?? 0;
    final abv = double.tryParse(_abastCtrl.text.replaceAll(',', '.')) ?? 0;
    final h = _parseH(_hCtrl.text.trim());

    if (_modoTotal) {
      final total = double.tryParse(_totalCtrl.text.replaceAll(',', '.')); 
      final nv = int.tryParse(_nViaCtrl.text.trim());
      if (total == null || total <= 0) { _snack('Informe o total ganho.'); return; }
      if (nv == null || nv <= 0) { _snack('Informe o número de viagens.'); return; }
      final mv = double.tryParse(_mTotalCtrl.text.replaceAll(',', '.'));
      if (mv != null && mv > 0) _meta = mv;
      final dt = _dataTotal;
      _confirm('Encerrar o dia?', 'Salvar ${fmtMoney(total)} em $nv viagens em ${fmtDate(dt)}?', () {
        widget.onEncerrarDia({'data': fmtDate(dt), 'dataISO': dt.toIso8601String(), 'semana': diaSemana(dt.weekday),
          'total': total, 'meta': _meta, 'viagens': nv, 'km': km, 'horas': h, 'abastecimento': abv,
          'liquido': total - abv, 'bateu': total >= _meta, 'modoTotal': true});
        _totalCtrl.clear(); _nViaCtrl.clear(); _mTotalCtrl.clear(); _kmCtrl.clear(); _hCtrl.clear(); _abastCtrl.clear();
        _snack('Dia ${fmtDate(dt)} salvo!');
      });
    } else {
      if (_viagens.isEmpty) { _snack('Adicione pelo menos uma viagem.'); return; }
      final ta = _abast + abv;
      final now = DateTime.now();
      _confirm('Encerrar o dia?', 'Salvar ${fmtMoney(_atual)} em ${_viagens.length} viagens?', () {
        widget.onEncerrarDia({'data': fmtDate(now), 'dataISO': now.toIso8601String(), 'semana': diaSemana(now.weekday),
          'total': _atual, 'meta': _meta, 'viagens': _viagens.length, 'km': km, 'horas': h,
          'abastecimento': ta, 'liquido': _atual - ta, 'bateu': _atual >= _meta, 'modoTotal': false,
          'historicoViagens': List.from(_viagens)});
        _kmCtrl.clear(); _hCtrl.clear(); _abastCtrl.clear();
        _snack('Dia encerrado e salvo!');
      });
    }
  }

  double _parseH(String s) {
    if (s.isEmpty) return 0;
    final c = s.replaceAll('h', ':').replaceAll(',', '.');
    if (c.contains(':')) { final p = c.split(':'); return (double.tryParse(p[0]) ?? 0) + (double.tryParse(p.length > 1 ? p[1] : '0') ?? 0) / 60; }
    return double.tryParse(c) ?? 0;
  }

  void _snack(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), duration: const Duration(seconds: 3)));

  void _confirm(String title, String body, VoidCallback onOk) {
    showDialog(context: context, builder: (_) => AlertDialog(
      title: Text(title), content: Text(body),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        TextButton(onPressed: () { Navigator.pop(context); onOk(); }, child: const Text('Confirmar')),
      ],
    ));
  }

  Future<void> _selecionarData() async {
    final p = await showDatePicker(context: context, initialDate: _dataTotal,
        firstDate: DateTime(2020), lastDate: DateTime.now(), locale: const Locale('pt', 'BR'));
    if (p != null) setState(() => _dataTotal = p);
  }

  @override
  Widget build(BuildContext context) {
    final dark = darkModeNotifier.value;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: Column(children: [
        // Stats
        Row(children: [
          StatPill(label: 'SALDO\nBRUTO', value: fmtMoney(_atual), valueColor: dark ? T.accent : T.lAccent),
          const SizedBox(width: 8),
          StatPill(label: 'ABASTEC.', value: fmtMoney(_abast), valueColor: _abast > 0 ? T.red : (dark ? T.textSecondary : T.lTextMuted)),
          const SizedBox(width: 8),
          StatPill(label: 'LÍQUIDO', value: fmtMoney(_liquido), valueColor: dark ? T.accent : T.lAccent),
          const SizedBox(width: 8),
          StatPill(label: 'VIAGENS', value: '$_countViagens', valueColor: dark ? T.textPrimary : T.lText),
        ]),
        const SizedBox(height: 14),

        // Barra meta
        AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('Meta: ${fmtMoney(_meta)}', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: dark ? T.textPrimary : T.lText)),
            Text(_falta <= 0 ? 'Meta atingida!' : 'falta ${fmtMoney(_falta)}',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                    color: _falta <= 0 ? (dark ? T.accent : T.lAccent) : T.red)),
          ]),
          const SizedBox(height: 12),
          ClipRRect(borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(value: _pct, minHeight: 8,
                backgroundColor: dark ? T.bgCardLight : const Color(0xFFE0E0E0),
                color: dark ? T.accent : T.lAccent)),
          const SizedBox(height: 8),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('${(_pct * 100).toStringAsFixed(0)}%',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: dark ? T.accent : T.lAccent)),
            Text(fmtMoney(_meta), style: TextStyle(fontSize: 12, color: dark ? T.textSecondary : T.lTextMuted)),
          ]),
        ])),
        const SizedBox(height: 14),

        // Registrar viagens
        AppCard(child: Column(children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('Registrar viagens', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: dark ? T.textPrimary : T.lText)),
          ]),
          const SizedBox(height: 12),
          // Toggle
          Container(
            decoration: BoxDecoration(color: dark ? T.bgInput : const Color(0xFFF0F0F0), borderRadius: BorderRadius.circular(12),
                border: Border.all(color: dark ? T.border : T.lBorder)),
            padding: const EdgeInsets.all(4),
            child: Row(children: [
              _tglBtn('Uma por uma', !_modoTotal, () => setState(() => _modoTotal = false), dark),
              _tglBtn('Total do dia', _modoTotal, () => setState(() => _modoTotal = true), dark),
            ]),
          ),
          const SizedBox(height: 14),
          if (!_modoTotal) ...[
            Row(children: [
              Expanded(child: AppInput(ctrl: _vCtrl, label: 'VALOR DA VIAGEM (R\$)', hint: '18.50')),
              const SizedBox(width: 10),
              Expanded(child: AppInput(ctrl: _mCtrl, label: 'META (R\$)', hint: '500')),
            ]),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () => setState(() => _ehPromo = !_ehPromo),
              child: Row(children: [
                AnimatedContainer(duration: const Duration(milliseconds: 150),
                  width: 22, height: 22,
                  decoration: BoxDecoration(
                    color: _ehPromo ? T.amber : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: _ehPromo ? T.amber : (dark ? T.borderBright : T.lBorder), width: 1.5)),
                  child: _ehPromo ? const Icon(Icons.check, size: 14, color: Colors.black) : null),
                const SizedBox(width: 10),
                Text('É promoção/bônus', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                    color: _ehPromo ? T.amber : (dark ? T.textSecondary : T.lTextMuted))),
                const SizedBox(width: 6),
                Text('(não conta nas viagens)', style: TextStyle(fontSize: 11, color: dark ? T.textDim : T.lTextDim)),
              ]),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: PrimaryBtn(label: '+ Viagem', onTap: _addViagem)),
              const SizedBox(width: 8),
              Expanded(child: PrimaryBtn(label: 'Salvar meta', onTap: _setMeta, isSecondary: true)),
              const SizedBox(width: 8),
              Expanded(child: PrimaryBtn(label: 'Zerar', onTap: _zerar, isDanger: true)),
            ]),
          ] else ...[
            GestureDetector(
              onTap: _selecionarData,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(color: dark ? T.bgInput : const Color(0xFFF5F5F0),
                    borderRadius: BorderRadius.circular(12), border: Border.all(color: dark ? T.border : T.lBorder)),
                child: Row(children: [
                  Icon(Icons.calendar_today_outlined, size: 16, color: dark ? T.accent : T.lAccent),
                  const SizedBox(width: 10),
                  Text(fmtDate(_dataTotal), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
                      color: dark ? T.textPrimary : T.lText)),
                  const Spacer(),
                  Text('alterar', style: TextStyle(fontSize: 11, color: dark ? T.textSecondary : T.lTextMuted)),
                ]),
              ),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: AppInput(ctrl: _totalCtrl, label: 'TOTAL GANHO (R\$)', hint: 'ex: 280.00')),
              const SizedBox(width: 10),
              Expanded(child: AppInput(ctrl: _nViaCtrl, label: 'Nº DE VIAGENS', hint: 'ex: 15')),
            ]),
            const SizedBox(height: 10),
            AppInput(ctrl: _mTotalCtrl, label: 'META DO DIA (R\$)', hint: '500'),
            const SizedBox(height: 8),
            Text('Preencha os dados do expediente na seção abaixo',
                style: TextStyle(fontSize: 11, color: dark ? T.textSecondary : T.lTextMuted)),
          ],
        ])),
        const SizedBox(height: 14),

        // Encerrar dia
        AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Encerrar o dia', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: dark ? T.textPrimary : T.lText)),
          const SizedBox(height: 4),
          Divider(color: dark ? T.border : T.lBorder),
          const SizedBox(height: 4),
          Text('DADOS DO EXPEDIENTE', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, letterSpacing: 0.8,
              color: dark ? T.textSecondary : T.lTextMuted)),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: AppInput(ctrl: _kmCtrl, label: 'KM RODADOS', hint: 'ex: 187')),
            const SizedBox(width: 10),
            Expanded(child: AppInput(ctrl: _hCtrl, label: 'HORAS TRABALHADAS', hint: 'ex: 8h30')),
          ]),
          const SizedBox(height: 10),
          SizedBox(width: (MediaQuery.of(context).size.width - 52) / 2,
            child: AppInput(ctrl: _abastCtrl, label: 'ABASTECIMENTO (R\$)', hint: 'ex: 80.00')),
          const SizedBox(height: 16),
          Divider(color: dark ? T.border : T.lBorder),
          const SizedBox(height: 12),
          PrimaryBtn(label: '+ Encerrar dia e salvar', onTap: _encerrarDia),
          const SizedBox(height: 8),
          Center(child: Text('salva no Diário e zera o contador de hoje',
              style: TextStyle(fontSize: 11, color: dark ? T.textSecondary : T.lTextMuted))),
        ])),
        const SizedBox(height: 14),

        // Histórico
        if (!_modoTotal && _viagens.isNotEmpty)
          AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('Viagens de hoje', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: dark ? T.textPrimary : T.lText)),
              Text(() {
                final n = _viagens.where((v) => v['promo'] != true).length;
                final p = _viagens.where((v) => v['promo'] == true).length;
                return '$n viagens${p > 0 ? ' · $p promo' : ''} · ${fmtMoney(_media)}/viag.';
              }(), style: TextStyle(fontSize: 10, color: dark ? T.textSecondary : T.lTextMuted)),
            ]),
            const SizedBox(height: 12),
            ..._viagens.reversed.take(30).toList().asMap().entries.map((e) {
              final orig = _viagens.length - 1 - e.key;
              final v = e.value;
              final isPromo = v['promo'] == true;
              final numN = isPromo ? 0 : _viagens.sublist(0, orig + 1).where((x) => x['promo'] != true).length;
              return Padding(padding: const EdgeInsets.only(bottom: 8),
                child: Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                    decoration: BoxDecoration(
                      color: isPromo ? T.amber.withOpacity(0.15) : (dark ? T.accentDim.withOpacity(0.2) : T.lAccent.withOpacity(0.1)),
                      borderRadius: BorderRadius.circular(99),
                      border: Border.all(color: isPromo ? T.amber.withOpacity(0.4) : (dark ? T.accentDim : T.lAccent).withOpacity(0.3)),
                    ),
                    child: Text(isPromo ? 'promo' : '#$numN',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                            color: isPromo ? T.amber : (dark ? T.accent : T.lAccent)))),
                  const SizedBox(width: 8),
                  Text(v['hora'] ?? '', style: TextStyle(fontSize: 11, color: dark ? T.textSecondary : T.lTextMuted)),
                  const Spacer(),
                  Text('+${fmtMoney((v['val'] as num).toDouble())}',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
                          color: isPromo ? T.amber : (dark ? T.accent : T.lAccent))),
                  const SizedBox(width: 8),
                  GestureDetector(onTap: () => _removeViagem(orig),
                    child: Container(padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(color: T.red.withOpacity(0.12), borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: T.red.withOpacity(0.3))),
                      child: const Icon(Icons.close, size: 13, color: T.red))),
                ]));
            }),
          ])),
      ]),
    );
  }

  Widget _tglBtn(String label, bool active, VoidCallback onTap, bool dark) => Expanded(
    child: GestureDetector(onTap: onTap,
      child: AnimatedContainer(duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: active ? (dark ? T.accentDim : T.lAccent) : Colors.transparent,
          borderRadius: BorderRadius.circular(10)),
        child: Text(label, textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                color: active ? Colors.white : (dark ? T.textSecondary : T.lTextMuted))))));
}

// ─── ABA DIÁRIO ───────────────────────────────────────────────────────────────
class DiarioTab extends StatefulWidget {
  final List<Map<String, dynamic>> dias;
  final Function(int) onDeleteDia;
  const DiarioTab({super.key, required this.dias, required this.onDeleteDia});
  @override State<DiarioTab> createState() => _DiarioTabState();
}

class _DiarioTabState extends State<DiarioTab> {
  DateTime? _filtro;

  List<Map<String, dynamic>> get _filtrados {
    if (_filtro == null) return widget.dias;
    final alvo = fmtDate(_filtro!);
    return widget.dias.where((d) => (d['data'] as String? ?? '') == alvo).toList();
  }

  Future<void> _selecionarFiltro() async {
    final p = await showDatePicker(context: context, initialDate: _filtro ?? DateTime.now(),
        firstDate: DateTime(2020), lastDate: DateTime.now(), locale: const Locale('pt', 'BR'));
    if (p != null) setState(() => _filtro = p);
  }

  @override
  Widget build(BuildContext context) {
    final dark = darkModeNotifier.value;
    final dias = _filtrados;
    if (widget.dias.isEmpty) return Center(child: Text('Nenhum dia registrado ainda.\nEncerre o primeiro dia na aba Hoje!',
        textAlign: TextAlign.center, style: TextStyle(color: dark ? T.textSecondary : T.lTextMuted, fontSize: 14)));

    final batidas = widget.dias.where((d) => d['bateu'] == true).length;
    final pct = (batidas / widget.dias.length * 100).round();
    final kmTotal = widget.dias.fold<double>(0, (s, d) => s + (d['km'] as num? ?? 0).toDouble());

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: Column(children: [
        Row(children: [
          _mini('DIAS', '${widget.dias.length}', dark ? T.textPrimary : T.lText, dark),
          const SizedBox(width: 8),
          _mini('METAS', '$batidas/${widget.dias.length}', dark ? T.accent : T.lAccent, dark),
          const SizedBox(width: 8),
          _mini('APROVEIT.', '$pct%', T.amber, dark),
          const SizedBox(width: 8),
          _mini('KM TOTAL', '${kmTotal.toStringAsFixed(0)}', T.blue, dark),
        ]),
        const SizedBox(height: 12),

        // Filtro de data
        Row(children: [
          Expanded(child: GestureDetector(
            onTap: _selecionarFiltro,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: _filtro != null ? T.accentDim.withOpacity(0.15) : (dark ? T.bgCard : T.lCard),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _filtro != null ? T.accentDim : (dark ? T.border : T.lBorder)),
              ),
              child: Row(children: [
                Icon(Icons.calendar_today_outlined, size: 15,
                    color: _filtro != null ? (dark ? T.accent : T.lAccent) : (dark ? T.textSecondary : T.lTextMuted)),
                const SizedBox(width: 8),
                Text(_filtro != null ? fmtDate(_filtro!) : 'Filtrar por data',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                        color: _filtro != null ? (dark ? T.accent : T.lAccent) : (dark ? T.textSecondary : T.lTextMuted))),
              ]),
            ),
          )),
          if (_filtro != null) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => setState(() => _filtro = null),
              child: Container(padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: dark ? T.bgCard : T.lCardAlt,
                    borderRadius: BorderRadius.circular(12), border: Border.all(color: dark ? T.border : T.lBorder)),
                child: Icon(Icons.close, size: 16, color: dark ? T.textSecondary : T.lTextMuted))),
          ],
        ]),
        const SizedBox(height: 12),

        if (dias.isEmpty)
          AppCard(child: Center(child: Padding(padding: const EdgeInsets.all(8),
            child: Text('Nenhum registro em ${fmtDate(_filtro!)}.',
                style: TextStyle(color: dark ? T.textSecondary : T.lTextMuted)))))
        else
          ...dias.asMap().entries.map((e) => _dayCard(e.key, e.value, dark)),
      ]),
    );
  }

  Widget _dayCard(int i, Map<String, dynamic> d, bool dark) {
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
    final temHist = !modoTotal && historico != null && historico.isNotEmpty;

    return Padding(padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: temHist ? () => _abrirHistorico(d, historico) : null,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: dark ? T.bgCard : T.lCard,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: temHist ? T.accentDim : (dark ? T.border : T.lBorder), width: temHist ? 1.5 : 1)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Text(d['data'] ?? '', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: dark ? T.textPrimary : T.lText)),
                  if (temHist) ...[const SizedBox(width: 6), Icon(Icons.expand_more, size: 16, color: dark ? T.accent : T.lAccent)],
                ]),
                Text(d['semana'] ?? '', style: TextStyle(fontSize: 11, color: dark ? T.textSecondary : T.lTextMuted)),
              ]),
              Row(children: [
                Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: bateu ? T.accentDim.withOpacity(0.15) : T.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(color: bateu ? T.accentDim.withOpacity(0.5) : T.red.withOpacity(0.3))),
                  child: Text(bateu ? 'Meta batida' : 'Não bateu',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                          color: bateu ? (dark ? T.accent : T.lAccent) : T.red))),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => showDialog(context: context, builder: (_) => AlertDialog(
                    title: const Text('Excluir dia?'),
                    content: Text('O registro de ${d['data']} será apagado.'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
                      TextButton(onPressed: () { widget.onDeleteDia(i); Navigator.pop(context); },
                          child: const Text('Excluir', style: TextStyle(color: Colors.red))),
                    ],
                  )),
                  child: Container(padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(color: dark ? T.bgCardLight : T.lCardAlt, borderRadius: BorderRadius.circular(8)),
                    child: Icon(Icons.close, size: 13, color: dark ? T.textSecondary : T.lTextMuted))),
              ]),
            ]),
            const SizedBox(height: 12),
            Divider(color: dark ? T.border : T.lBorder, height: 1),
            const SizedBox(height: 12),
            _dRow('Total bruto', fmtMoney(total), bateu ? (dark ? T.accent : T.lAccent) : T.red, dark),
            if (abast > 0) ...[
              const SizedBox(height: 6),
              _dRow('Abastecimento', '-${fmtMoney(abast)}', T.red, dark),
              const SizedBox(height: 6),
              _dRow('Líquido', fmtMoney(liquido), T.blue, dark, bold: true),
            ],
            const SizedBox(height: 6),
            _dRow('Meta do dia', fmtMoney(meta), dark ? T.textPrimary : T.lText, dark),
            const SizedBox(height: 6),
            _dRow('Viagens · km · horas',
              '$viagens${km > 0 ? ' · ${km.toStringAsFixed(0)}km' : ''}${horas > 0 ? ' · ${fmtH(horas)}' : ''}',
              dark ? T.textPrimary : T.lText, dark),
            if (km > 0 || horas > 0) ...[
              const SizedBox(height: 12),
              Row(children: [
                if (horas > 0) Expanded(child: _mCard('Ganho por hora', 'R\$ ${ganhoH.toStringAsFixed(2).replaceAll('.', ',')}/h', dark)),
                if (horas > 0 && km > 0) const SizedBox(width: 8),
                if (km > 0) Expanded(child: _mCard('Ganho por km', 'R\$ ${ganhoKm.toStringAsFixed(2).replaceAll('.', ',')}/km', dark)),
              ]),
            ],
            const SizedBox(height: 12),
            ClipRRect(borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(value: pctDia, minHeight: 6,
                backgroundColor: dark ? T.bgCardLight : const Color(0xFFE0E0E0),
                color: bateu ? (dark ? T.accent : T.lAccent) : T.red)),
            const SizedBox(height: 6),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('${(pctDia * 100).toStringAsFixed(0)}%',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                      color: bateu ? (dark ? T.accent : T.lAccent) : T.red)),
              Text(fmtMoney(meta), style: TextStyle(fontSize: 10, color: dark ? T.textSecondary : T.lTextMuted)),
            ]),
            if (temHist) ...[
              const SizedBox(height: 10),
              Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: dark ? T.accentDim.withOpacity(0.1) : T.lAccent.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: dark ? T.accentDim.withOpacity(0.3) : T.lAccent.withOpacity(0.2))),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.touch_app_outlined, size: 13, color: dark ? T.accent : T.lAccent),
                  const SizedBox(width: 6),
                  Text('toque para ver o histórico de viagens',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: dark ? T.accent : T.lAccent)),
                ])),
            ],
          ]),
        )));
  }

  Widget _dRow(String label, String val, Color valColor, bool dark, {bool bold = false}) =>
    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: TextStyle(fontSize: 12, color: dark ? T.textSecondary : T.lTextMuted)),
      Text(val, style: TextStyle(fontSize: 13, fontWeight: bold ? FontWeight.w700 : FontWeight.w600, color: valColor)),
    ]);

  Widget _mCard(String label, String val, bool dark) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(color: dark ? T.bgCardLight : T.lCardAlt, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: dark ? T.border : T.lBorder)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, letterSpacing: 0.5, color: dark ? T.textSecondary : T.lTextMuted)),
      const SizedBox(height: 4),
      Text(val, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: dark ? T.accent : T.lAccent)),
    ]));

  Widget _mini(String label, String val, Color color, bool dark) => Expanded(
    child: Container(padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: dark ? T.bgCard : T.lCard, borderRadius: BorderRadius.circular(14),
          border: Border.all(color: dark ? T.border : T.lBorder)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(fontSize: 8, fontWeight: FontWeight.w700, letterSpacing: 0.5,
            color: dark ? T.textSecondary : T.lTextMuted)),
        const SizedBox(height: 4),
        Text(val, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
      ])));

  void _abrirHistorico(Map<String, dynamic> d, List historico) {
    final dark = darkModeNotifier.value;
    showModalBottomSheet(
      context: context, isScrollControlled: true, isDismissible: true, enableDrag: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => GestureDetector(
        onTap: () => Navigator.pop(sheetCtx),
        behavior: HitTestBehavior.opaque,
        child: DraggableScrollableSheet(initialChildSize: 0.6, maxChildSize: 0.9, minChildSize: 0.3,
          builder: (_, ctrl) => GestureDetector(onTap: () {},
            child: Container(
              decoration: BoxDecoration(color: dark ? T.bgCard : T.lCard,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
              child: Column(children: [
                Container(margin: const EdgeInsets.only(top: 12), width: 40, height: 4,
                    decoration: BoxDecoration(color: dark ? T.border : T.lBorder, borderRadius: BorderRadius.circular(99))),
                Padding(padding: const EdgeInsets.all(16),
                  child: Row(children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${d['data']} · ${d['semana']}',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: dark ? T.textPrimary : T.lText)),
                      Text('${historico.length} viagens · ${fmtMoney((d['total'] as num).toDouble())}',
                          style: TextStyle(fontSize: 12, color: dark ? T.textSecondary : T.lTextMuted)),
                    ])),
                  ])),
                Divider(color: dark ? T.border : T.lBorder, height: 1),
                Expanded(child: ListView.builder(
                  controller: ctrl, padding: const EdgeInsets.all(16),
                  itemCount: historico.length,
                  itemBuilder: (_, i) {
                    final v = historico[i] as Map;
                    final isPromo = v['promo'] == true;
                    return Padding(padding: const EdgeInsets.only(bottom: 10),
                      child: Row(children: [
                        Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                          decoration: BoxDecoration(
                            color: isPromo ? T.amber.withOpacity(0.15) : (dark ? T.accentDim.withOpacity(0.15) : T.lAccent.withOpacity(0.1)),
                            borderRadius: BorderRadius.circular(99),
                            border: Border.all(color: isPromo ? T.amber.withOpacity(0.4) : (dark ? T.accentDim : T.lAccent).withOpacity(0.3))),
                          child: Text(isPromo ? 'promo' : '#${i + 1}',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                                  color: isPromo ? T.amber : (dark ? T.accent : T.lAccent)))),
                        const SizedBox(width: 10),
                        Text(v['hora']?.toString() ?? '', style: TextStyle(fontSize: 12, color: dark ? T.textSecondary : T.lTextMuted)),
                        const Spacer(),
                        Text('+R\$ ${(v['val'] as num).toStringAsFixed(2).replaceAll('.', ',')}',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700,
                                color: isPromo ? T.amber : (dark ? T.accent : T.lAccent))),
                      ]));
                  },
                )),
              ]),
            )),
        ),
      ),
    );
  }
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
      else _inicio = now.subtract(Duration(days: int.tryParse(q) ?? 30));
    });
  }

  void _tapDia(DateTime dia) {
    setState(() {
      if (_tapInicio == null) { _tapInicio = DateTime(dia.year, dia.month, dia.day); _inicio = _tapInicio; _fim = _tapInicio; _quickSel = ''; }
      else {
        final fim = DateTime(dia.year, dia.month, dia.day);
        if (fim.isBefore(_tapInicio!)) { _inicio = fim; _fim = _tapInicio; } else { _inicio = _tapInicio; _fim = fim; }
        _tapInicio = null; _quickSel = '';
      }
    });
  }

  List<Map<String, dynamic>> get _filtrados {
    if (_inicio == null || _fim == null) return widget.dias;
    final fimDia = DateTime(_fim!.year, _fim!.month, _fim!.day, 23, 59, 59);
    return widget.dias.where((d) {
      try {
        final iso = d['dataISO'] as String?;
        final dt = iso != null ? DateTime.parse(iso) : DateTime(int.parse((d['data'] as String).split('/')[2]), int.parse((d['data'] as String).split('/')[1]), int.parse((d['data'] as String).split('/')[0]));
        return !dt.isBefore(_inicio!) && !dt.isAfter(fimDia);
      } catch (_) { return true; }
    }).toList();
  }

  bool _isStart(DateTime d) => _inicio != null && d.year == _inicio!.year && d.month == _inicio!.month && d.day == _inicio!.day;
  bool _isEnd(DateTime d) => _fim != null && d.year == _fim!.year && d.month == _fim!.month && d.day == _fim!.day;
  bool _isInRange(DateTime d) => _inicio != null && _fim != null && !d.isBefore(_inicio!) && !d.isAfter(_fim!);
  bool _isToday(DateTime d) { final n = DateTime.now(); return d.year == n.year && d.month == n.month && d.day == n.day; }

  @override
  Widget build(BuildContext context) {
    final dark = darkModeNotifier.value;
    final dias = _filtrados;
    final meses = ['Janeiro','Fevereiro','Março','Abril','Maio','Junho','Julho','Agosto','Setembro','Outubro','Novembro','Dezembro'];

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: Column(children: [
        // Filtro
        GestureDetector(
          onTap: () => setState(() => _showCal = !_showCal),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: _showCal ? T.accentDim.withOpacity(0.15) : (dark ? T.bgCard : T.lCard),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _showCal ? T.accentDim : (dark ? T.border : T.lBorder))),
            child: Row(children: [
              Icon(Icons.calendar_month_outlined, size: 16, color: dark ? T.accent : T.lAccent),
              const SizedBox(width: 10),
              Expanded(child: Text(
                _inicio != null && _fim != null ? '${fmtDate(_inicio!)}  →  ${fmtDate(_fim!)}' : 'Selecionar período',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                    color: dark ? T.textPrimary : T.lText))),
              Icon(_showCal ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                  size: 18, color: dark ? T.textSecondary : T.lTextMuted),
            ]),
          ),
        ),
        const SizedBox(height: 10),

        // Chips
        SingleChildScrollView(scrollDirection: Axis.horizontal,
          child: Row(children: [
            for (final q in [('hoje','Hoje'),('7','7 dias'),('30','30 dias'),('mes','Este mês'),('ano','Este ano'),('tudo','Todo período')])
              Padding(padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(onTap: () => _aplicarQuick(q.$1),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: _quickSel == q.$1 ? (dark ? T.accentDim : T.lAccent) : (dark ? T.bgCard : T.lCardAlt),
                      borderRadius: BorderRadius.circular(99),
                      border: Border.all(color: _quickSel == q.$1 ? Colors.transparent : (dark ? T.border : T.lBorder))),
                    child: Text(q.$2, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                        color: _quickSel == q.$1 ? Colors.white : (dark ? T.textSecondary : T.lTextMuted)))))),
          ])),
        const SizedBox(height: 10),

        // Calendário
        if (_showCal) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: dark ? T.bgCard : T.lCard, borderRadius: BorderRadius.circular(20),
                border: Border.all(color: dark ? T.border : T.lBorder)),
            child: Column(children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                GestureDetector(onTap: () => setState(() => _calMes = DateTime(_calMes.year, _calMes.month - 1)),
                  child: Padding(padding: const EdgeInsets.all(6), child: Icon(Icons.chevron_left, size: 22, color: dark ? T.textSecondary : T.lTextMuted))),
                Text('${meses[_calMes.month - 1]} ${_calMes.year}',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: dark ? T.textPrimary : T.lText)),
                GestureDetector(onTap: () => setState(() => _calMes = DateTime(_calMes.year, _calMes.month + 1)),
                  child: Padding(padding: const EdgeInsets.all(6), child: Icon(Icons.chevron_right, size: 22, color: dark ? T.textSecondary : T.lTextMuted))),
              ]),
              const SizedBox(height: 10),
              Row(children: ['D','S','T','Q','Q','S','S'].map((d) => Expanded(
                child: Center(child: Text(d, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                    color: dark ? T.textSecondary : T.lTextMuted))))).toList()),
              const SizedBox(height: 6),
              Builder(builder: (_) {
                final firstDay = DateTime(_calMes.year, _calMes.month, 1);
                final daysInMonth = DateTime(_calMes.year, _calMes.month + 1, 0).day;
                final startWeekday = firstDay.weekday % 7;
                return GridView.builder(
                  shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7, childAspectRatio: 1),
                  itemCount: startWeekday + daysInMonth,
                  itemBuilder: (_, idx) {
                    if (idx < startWeekday) return const SizedBox();
                    final dia = DateTime(_calMes.year, _calMes.month, idx - startWeekday + 1);
                    final start = _isStart(dia), end = _isEnd(dia) && !start;
                    final inRange = _isInRange(dia) && !start && !end;
                    final today = _isToday(dia);
                    Color bg = Colors.transparent, fg = dark ? T.textPrimary : T.lText;
                    BorderRadius br = BorderRadius.circular(6);
                    if (start || end) { bg = dark ? T.accent : T.lAccent; fg = dark ? Colors.black : Colors.white; br = BorderRadius.circular(99); }
                    else if (inRange) { bg = dark ? T.accentDim.withOpacity(0.2) : T.lAccent.withOpacity(0.1); fg = dark ? T.accent : T.lAccent; br = BorderRadius.zero; }
                    else if (today) { bg = T.blue.withOpacity(0.2); fg = T.blue; br = BorderRadius.circular(99); }
                    return GestureDetector(onTap: () => _tapDia(dia),
                      child: Container(decoration: BoxDecoration(color: bg, borderRadius: br),
                        child: Center(child: Text('${dia.day}', style: TextStyle(fontSize: 11,
                            fontWeight: (start || end) ? FontWeight.w700 : FontWeight.normal, color: fg)))));
                  });
              }),
              const SizedBox(height: 8),
              Text(_tapInicio != null ? 'Toque no dia final do período' : 'Toque em dois dias para selecionar o período',
                  style: TextStyle(fontSize: 11, color: dark ? T.textSecondary : T.lTextMuted, fontStyle: FontStyle.italic)),
            ]),
          ),
          const SizedBox(height: 10),
        ],

        // Resultados
        if (dias.isEmpty)
          AppCard(child: Center(child: Padding(padding: const EdgeInsets.all(8),
            child: Text('Nenhum dia no período selecionado.',
                style: TextStyle(color: dark ? T.textSecondary : T.lTextMuted)))))
        else
          _buildResultados(dias, dark),
      ]),
    );
  }

  Widget _buildResultados(List<Map<String, dynamic>> dias, bool dark) {
    final totalGanho = dias.fold<double>(0, (s, d) => s + (d['total'] as num).toDouble());
    final totalKm = dias.fold<double>(0, (s, d) => s + (d['km'] as num? ?? 0).toDouble());
    final totalHoras = dias.fold<double>(0, (s, d) => s + (d['horas'] as num? ?? 0).toDouble());
    final totalViagens = dias.fold<int>(0, (s, d) => s + (d['viagens'] as int? ?? 0));
    final totalAbast = dias.fold<double>(0, (s, d) => s + (d['abastecimento'] as num? ?? 0).toDouble());
    final batidas = dias.where((d) => d['bateu'] == true).length;
    final pct = (batidas / dias.length * 100).round();
    final liquido = totalGanho - totalAbast;

    return Column(children: [
      // Total card
      Container(
        width: double.infinity, padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: dark ? T.bgCard : T.lCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: dark ? T.accentDim.withOpacity(0.3) : T.lAccent.withOpacity(0.3), width: 1.5)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Total ganho (${dias.length} dias)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
              letterSpacing: 0.5, color: dark ? T.textSecondary : T.lTextMuted)),
          const SizedBox(height: 6),
          Text(fmtMoney(totalGanho), style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800,
              color: dark ? T.accent : T.lAccent)),
          if (totalAbast > 0) ...[
            const SizedBox(height: 8),
            Row(children: [
              Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: T.red.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: Text('abastec. -${fmtMoney(totalAbast)}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: T.red))),
              const SizedBox(width: 8),
              Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: T.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: Text('líquido ${fmtMoney(liquido)}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: T.blue))),
            ]),
          ],
        ])),
      const SizedBox(height: 10),
      GridView.count(crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 2.0,
        children: [
          _rCard('Dias trabalhados', '${dias.length}', dark ? T.textPrimary : T.lText, dark),
          _rCard('Metas batidas', '$batidas de ${dias.length}', dark ? T.accent : T.lAccent, dark),
          _rCard('Aproveitamento', '$pct%', pct >= 70 ? (dark ? T.accent : T.lAccent) : T.amber, dark),
          _rCard('Total viagens', '$totalViagens', dark ? T.textPrimary : T.lText, dark),
          _rCard('Km rodados', '${totalKm.toStringAsFixed(0)} km', T.blue, dark),
          _rCard('Horas trabalhadas', fmtH(totalHoras), dark ? T.textPrimary : T.lText, dark),
        ]),
      const SizedBox(height: 10),
      AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('MÉDIAS DO PERÍODO', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 0.8,
            color: dark ? T.textSecondary : T.lTextMuted)),
        const SizedBox(height: 14),
        _mRow('Ganho por dia', fmtMoney(totalGanho / dias.length), dark),
        if (totalViagens > 0) _mRow('Ganho por viagem', fmtMoney(totalGanho / totalViagens), dark),
        if (totalHoras > 0) _mRow('Ganho por hora', 'R\$ ${(totalGanho / totalHoras).toStringAsFixed(2).replaceAll('.', ',')}/h', dark),
        if (totalKm > 0) _mRow('Ganho por km', 'R\$ ${(totalGanho / totalKm).toStringAsFixed(2).replaceAll('.', ',')}/km', dark),
        if (totalAbast > 0) _mRow('Líquido por dia', fmtMoney(liquido / dias.length), dark),
        if (totalViagens > 0 && dias.isNotEmpty) _mRow('Viagens por dia', (totalViagens / dias.length).toStringAsFixed(1), dark),
      ])),
    ]);
  }

  Widget _rCard(String label, String val, Color color, bool dark) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: dark ? T.bgCard : T.lCard, borderRadius: BorderRadius.circular(16),
        border: Border.all(color: dark ? T.border : T.lBorder)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, letterSpacing: 0.5,
          color: dark ? T.textSecondary : T.lTextMuted)),
      const SizedBox(height: 6),
      Text(val, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: color)),
    ]));

  Widget _mRow(String label, String val, bool dark) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: TextStyle(fontSize: 13, color: dark ? T.textSecondary : T.lTextMuted)),
      Text(val, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: dark ? T.textPrimary : T.lText)),
    ]));
}
