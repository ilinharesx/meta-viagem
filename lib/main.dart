import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MetaViagemApp());
}

@pragma("vm:entry-point")
void overlayMain() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const OverlayWidget());
}

class MetaViagemApp extends StatelessWidget {
  const MetaViagemApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Meta Viagem',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(colorSchemeSeed: const Color(0xFF1D9E75), useMaterial3: true),
    home: const RootPage(),
  );
}

// ─── ROOT ─────────────────────────────────────────────────────────────────────

class RootPage extends StatefulWidget {
  const RootPage({super.key});
  @override
  State<RootPage> createState() => _RootPageState();
}

class _RootPageState extends State<RootPage> with WidgetsBindingObserver {
  int _tab = 0;
  double _atual = 0, _meta = 500, _abastecimento = 0;
  List<Map<String, dynamic>> _viagens = [];
  List<Map<String, dynamic>> _dias = [];
  bool _overlayActive = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() { WidgetsBinding.instance.removeObserver(this); super.dispose(); }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed) _checkOverlay();
  }

  Future<void> _checkOverlay() async {
    try { final a = await FlutterOverlayWindow.isActive(); if (mounted) setState(() => _overlayActive = a); } catch (_) {}
  }

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
    try { FlutterOverlayWindow.shareData({'atual': _atual, 'meta': _meta, 'viagens': _viagens.length}); } catch (_) {}
  }

  void _onHojeChanged(double atual, double meta, double abast, List<Map<String, dynamic>> viagens) {
    setState(() { _atual = atual; _meta = meta; _abastecimento = abast; _viagens = viagens; });
    _save();
  }

  void _onEncerrarDia(Map<String, dynamic> dia) {
    setState(() { _dias.insert(0, dia); _atual = 0; _viagens = []; _abastecimento = 0; });
    _save();
  }

  Future<void> _toggleOverlay() async {
    try {
      if (!await FlutterOverlayWindow.isPermissionGranted()) {
        await FlutterOverlayWindow.requestPermission(); return;
      }
      final active = await FlutterOverlayWindow.isActive();
      if (active) {
        await FlutterOverlayWindow.closeOverlay(); setState(() => _overlayActive = false);
      } else {
        await FlutterOverlayWindow.showOverlay(
          enableDrag: true, overlayTitle: 'Meta Viagem', overlayContent: 'Widget ativo',
          flag: OverlayFlag.focusPointer, visibility: NotificationVisibility.visibilityPublic,
          positionGravity: PositionGravity.auto, width: WindowSize.matchParent, height: 110,
          startPosition: const OverlayPosition(0, -200),
        );
        await Future.delayed(const Duration(milliseconds: 500));
        FlutterOverlayWindow.shareData({'atual': _atual, 'meta': _meta, 'viagens': _viagens.length});
        setState(() => _overlayActive = true);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final tabs = ['Hoje', 'Diário', 'Resumo'];
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F0),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5F5F0),
        title: const Text('Meta Viagem', style: TextStyle(fontWeight: FontWeight.w500)),
        actions: [IconButton(
          icon: Icon(_overlayActive ? Icons.picture_in_picture : Icons.picture_in_picture_outlined,
              color: _overlayActive ? const Color(0xFF1D9E75) : Colors.black45),
          onPressed: _toggleOverlay,
        )],
      ),
      body: Column(children: [
        Padding(padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            decoration: BoxDecoration(color: const Color(0xFFE8E8E2), borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.all(3),
            child: Row(children: List.generate(3, (i) => Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _tab = i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: _tab == i ? Colors.white : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(tabs[i], textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500,
                          color: _tab == i ? Colors.black87 : Colors.black45)),
                ),
              ),
            ))),
          )),
        const SizedBox(height: 12),
        Expanded(child: _tab == 0
          ? HojeTab(atual: _atual, meta: _meta, abastecimento: _abastecimento, viagens: _viagens,
              onChanged: _onHojeChanged, onEncerrarDia: _onEncerrarDia)
          : _tab == 1
          ? DiarioTab(dias: _dias, onDeleteDia: (i) { setState(() => _dias.removeAt(i)); _save(); })
          : ResumoTab(dias: _dias)),
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
  final _corridaCtrl = TextEditingController();
  final _metaCtrl = TextEditingController();
  final _totalCtrl = TextEditingController();
  final _nViaCtrl = TextEditingController();
  final _metaTotalCtrl = TextEditingController();
  final _kmCtrl = TextEditingController();
  final _horasCtrl = TextEditingController();
  final _abastCtrl = TextEditingController();

  @override
  void initState() { super.initState(); _atual = widget.atual; _meta = widget.meta; _abast = widget.abastecimento; _viagens = List.from(widget.viagens); }
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
  double get _liquido => _atual - _abast;
  double get _media => _viagens.isEmpty ? 0 : _atual / _viagens.length;

  void _addViagem() {
    final val = double.tryParse(_corridaCtrl.text.replaceAll(',', '.'));
    if (val == null || val <= 0) return;
    setState(() { _atual += val; _viagens.add({'val': val, 'hora': TimeOfDay.now().format(context)}); });
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

  void _confirmarTotal() {
    final total = double.tryParse(_totalCtrl.text.replaceAll(',', '.'));
    final nVia = int.tryParse(_nViaCtrl.text.trim());
    final metaVal = double.tryParse(_metaTotalCtrl.text.replaceAll(',', '.'));
    if (total == null || total <= 0) { _showSnack('Informe o total ganho.'); return; }
    if (nVia == null || nVia <= 0) { _showSnack('Informe o número de viagens.'); return; }
    if (metaVal != null && metaVal > 0) setState(() => _meta = metaVal);
    setState(() {
      _atual = total;
      _viagens = List.generate(nVia, (i) => {'val': total / nVia, 'hora': '—'});
    });
    _totalCtrl.clear(); _nViaCtrl.clear(); _metaTotalCtrl.clear();
    _notify(); _showSnack('Total do dia registrado!');
  }

  void _encerrarDia() {
    if (_viagens.isEmpty) { _showSnack('Adicione pelo menos uma viagem antes de encerrar.'); return; }
    final km = double.tryParse(_kmCtrl.text.replaceAll(',', '.')) ?? 0;
    final abastVal = double.tryParse(_abastCtrl.text.replaceAll(',', '.')) ?? 0;
    double horas = 0;
    final ht = _horasCtrl.text.trim();
    if (ht.isNotEmpty) {
      final c = ht.replaceAll('h', ':').replaceAll(',', '.');
      if (c.contains(':')) { final p = c.split(':'); horas = (double.tryParse(p[0]) ?? 0) + (double.tryParse(p.length > 1 ? p[1] : '0') ?? 0) / 60; }
      else { horas = double.tryParse(c) ?? 0; }
    }
    final totalAbast = _abast + abastVal;
    showDialog(context: context, builder: (_) => AlertDialog(
      title: const Text('Encerrar o dia?'),
      content: Text('Salvar ${_fmt(_atual)} em ${_viagens.length} viagens no Diário?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        TextButton(onPressed: () {
          final now = DateTime.now();
          widget.onEncerrarDia({
            'data': '${now.day.toString().padLeft(2,'0')}/${now.month.toString().padLeft(2,'0')}/${now.year}',
            'dataISO': now.toIso8601String(),
            'semana': ['Segunda','Terça','Quarta','Quinta','Sexta','Sábado','Domingo'][now.weekday - 1],
            'total': _atual,
            'meta': _meta,
            'viagens': _viagens.length,
            'km': km,
            'horas': horas,
            'abastecimento': totalAbast,
            'liquido': _atual - totalAbast,
            'bateu': _atual >= _meta,
          });
          _kmCtrl.clear(); _horasCtrl.clear(); _abastCtrl.clear();
          Navigator.pop(context);
          _showSnack('Dia encerrado e salvo no Diário!');
        }, child: const Text('Encerrar', style: TextStyle(color: Color(0xFF1D9E75)))),
      ],
    ));
  }

  void _showSnack(String msg) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(msg), duration: const Duration(seconds: 3)));

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: Column(children: [
        // Stats topo
        Row(children: [
          _statCard('Saldo bruto', _fmt(_atual), const Color(0xFF1D9E75)),
          const SizedBox(width: 6),
          _statCard('Abastec.', _abast > 0 ? '-${_fmt(_abast)}' : 'R$ 0,00', const Color(0xFF993C1D)),
          const SizedBox(width: 6),
          _statCard('Líquido', _fmt(_liquido.clamp(0, double.infinity)), const Color(0xFF185FA5)),
          const SizedBox(width: 6),
          _statCard('Viagens', '${_viagens.length}', Colors.black87),
        ]),
        const SizedBox(height: 12),

        // Barra de progresso
        _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('Meta: ${_fmt(_meta)}', style: const TextStyle(fontSize: 13, color: Colors.black54)),
            Text(_falta <= 0 ? 'Meta atingida!' : 'falta ${_fmt(_falta)}',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500,
                    color: _falta <= 0 ? const Color(0xFF1D9E75) : const Color(0xFF993C1D))),
          ]),
          const SizedBox(height: 10),
          ClipRRect(borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(value: _pct, minHeight: 10,
                backgroundColor: const Color(0xFFEEEEEE), color: const Color(0xFF1D9E75))),
          const SizedBox(height: 6),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('${(_pct * 100).toStringAsFixed(0)}%',
                style: const TextStyle(fontSize: 11, color: Color(0xFF1D9E75), fontWeight: FontWeight.w500)),
            Text(_fmt(_meta), style: const TextStyle(fontSize: 11, color: Colors.black45)),
          ]),
        ])),
        const SizedBox(height: 12),

        // Registrar viagens com toggle
        _card(Column(children: [
          const Align(alignment: Alignment.centerLeft,
            child: Text('Registrar viagens', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.black54))),
          const SizedBox(height: 8),
          // Toggle
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
            // Modo uma por uma
            Row(children: [
              Expanded(child: _inputField(_corridaCtrl, 'Valor da viagem (R\$)', '18.50')),
              const SizedBox(width: 8),
              Expanded(child: _inputField(_metaCtrl, 'Meta (R\$)', '500')),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: _btn('+ Viagem', const Color(0xFF1D9E75), Colors.white, _addViagem)),
              const SizedBox(width: 6),
              Expanded(child: _btn('Salvar meta', Colors.white, Colors.black87, _setMeta, border: Colors.black26)),
              const SizedBox(width: 6),
              Expanded(child: _btn('Zerar', Colors.white, const Color(0xFF993C1D), _zerar, border: const Color(0xFFD85A30))),
            ]),
          ] else ...[
            // Modo total do dia
            Row(children: [
              Expanded(child: _inputField(_totalCtrl, 'Total ganho (R\$)', 'ex: 280.00')),
              const SizedBox(width: 8),
              Expanded(child: _inputField(_nViaCtrl, 'Nº de viagens', 'ex: 15')),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: _inputField(_metaTotalCtrl, 'Meta (R\$)', '500')),
              const SizedBox(width: 8),
              Expanded(child: Padding(padding: const EdgeInsets.only(top: 15),
                child: _btn('Confirmar', const Color(0xFF1D9E75), Colors.white, _confirmarTotal))),
            ]),
            const SizedBox(height: 4),
            const Text('preenche o saldo e viagens de uma vez',
                style: TextStyle(fontSize: 11, color: Colors.black38)),
          ],
        ])),
        const SizedBox(height: 12),

        // Encerrar o dia
        _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Encerrar o dia', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.black54)),
          const SizedBox(height: 10),
          Container(height: 0.5, color: Colors.black12),
          const SizedBox(height: 10),
          const Text('Dados do expediente', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Colors.black45)),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: _inputField(_kmCtrl, 'Km rodados', 'ex: 187')),
            const SizedBox(width: 8),
            Expanded(child: _inputField(_horasCtrl, 'Horas trabalhadas', 'ex: 8h30')),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: _inputField(_abastCtrl, 'Abastecimento (R\$)', 'ex: 80.00')),
            const SizedBox(width: 8),
            const Expanded(child: SizedBox()),
          ]),
          const SizedBox(height: 10),
          Container(height: 0.5, color: Colors.black12),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: _encerrarDia,
            child: Container(
              width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 13),
              decoration: BoxDecoration(color: const Color(0xFF1D9E75), borderRadius: BorderRadius.circular(10)),
              child: const Center(child: Text('+ Encerrar dia e salvar',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.white))),
            ),
          ),
          const SizedBox(height: 6),
          const Center(child: Text('salva no Diário e zera o contador de hoje',
              style: TextStyle(fontSize: 11, color: Colors.black38))),
        ])),
        const SizedBox(height: 12),

        // Histórico
        if (_viagens.isNotEmpty)
          _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('Viagens de hoje', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.black54)),
              Text('${_viagens.length} viagens · ${_fmt(_media)}/viagem',
                  style: const TextStyle(fontSize: 11, color: Colors.black38)),
            ]),
            const SizedBox(height: 10),
            ..._viagens.reversed.take(30).toList().asMap().entries.map((e) {
              final orig = _viagens.length - 1 - e.key;
              final v = e.value;
              return Padding(padding: const EdgeInsets.only(bottom: 6),
                child: Row(children: [
                  Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: const Color(0xFF9FE1CB), borderRadius: BorderRadius.circular(99)),
                    child: Text('#${orig + 1}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Color(0xFF085041)))),
                  const SizedBox(width: 8),
                  Text(v['hora'] ?? '', style: const TextStyle(fontSize: 11, color: Colors.black38)),
                  const Spacer(),
                  Text('+${_fmt((v['val'] as num).toDouble())}',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF1D9E75))),
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
                color: active ? Colors.black87 : Colors.black45)))));

  Widget _card(Widget child) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black12, width: 0.5)),
    child: child);

  Widget _statCard(String label, String value, Color color) => Expanded(
    child: Container(padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: const Color(0xFFEEEEEE), borderRadius: BorderRadius.circular(10)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 9, color: Colors.black45)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: color)),
      ])));

  Widget _inputField(TextEditingController ctrl, String label, String hint) =>
    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontSize: 11, color: Colors.black54)),
      const SizedBox(height: 4),
      TextField(controller: ctrl,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(hintText: hint, hintStyle: const TextStyle(fontSize: 13),
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.black26, width: 0.5)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.black26, width: 0.5)))),
    ]);

  Widget _btn(String label, Color bg, Color fg, VoidCallback onTap, {Color border = Colors.transparent}) =>
    GestureDetector(onTap: onTap,
      child: Container(padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8),
            border: Border.all(color: border, width: 0.5)),
        child: Center(child: Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: fg)))));
}

// ─── ABA DIÁRIO ───────────────────────────────────────────────────────────────

class DiarioTab extends StatelessWidget {
  final List<Map<String, dynamic>> dias;
  final Function(int) onDeleteDia;
  const DiarioTab({super.key, required this.dias, required this.onDeleteDia});

  String _fmt(double v) => 'R\$ ${v.toStringAsFixed(2).replaceAll('.', ',')}';
  String _fmtH(double h) { final hh = h.floor(); final mm = ((h-hh)*60).round(); return mm > 0 ? '${hh}h${mm.toString().padLeft(2,'0')}' : '${hh}h'; }

  @override
  Widget build(BuildContext context) {
    if (dias.isEmpty) return const Center(child: Text('Nenhum dia registrado ainda.\nEncerre o primeiro dia na aba Hoje!',
        textAlign: TextAlign.center, style: TextStyle(color: Colors.black38, fontSize: 14)));

    final batidas = dias.where((d) => d['bateu'] == true).length;
    final pct = (batidas / dias.length * 100).round();
    final kmTotal = dias.fold<double>(0, (s, d) => s + (d['km'] as num? ?? 0).toDouble());
    final abastTotal = dias.fold<double>(0, (s, d) => s + (d['abastecimento'] as num? ?? 0).toDouble());

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: Column(children: [
        Row(children: [
          _mini('dias', '${dias.length}', Colors.black87),
          const SizedBox(width: 6),
          _mini('metas', '$batidas/${{dias.length}}', const Color(0xFF1D9E75)),
          const SizedBox(width: 6),
          _mini('aproveit.', '$pct%', const Color(0xFFBA7517)),
          const SizedBox(width: 6),
          _mini('km total', '${kmTotal.toStringAsFixed(0)}', const Color(0xFF185FA5)),
        ]),
        const SizedBox(height: 14),
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
          final pctDia = meta > 0 ? (total / meta).clamp(0.0, 1.0) : 0.0;
          final ganhoH = horas > 0 ? total / horas : 0.0;
          final ganhoKm = km > 0 ? total / km : 0.0;

          return Padding(padding: const EdgeInsets.only(bottom: 10),
            child: Container(padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.black12, width: 0.5)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(d['data'] ?? '', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                    Text(d['semana'] ?? '', style: const TextStyle(fontSize: 10, color: Colors.black38)),
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
                    GestureDetector(onTap: () => showDialog(context: context, builder: (_) => AlertDialog(
                      title: const Text('Excluir dia?'),
                      content: Text('O registro de ${d['data']} será apagado.'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
                        TextButton(onPressed: () { onDeleteDia(i); Navigator.pop(context); },
                            child: const Text('Excluir', style: TextStyle(color: Colors.red))),
                      ],
                    )),
                      child: Container(padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(color: const Color(0xFFF1EFE8), borderRadius: BorderRadius.circular(6)),
                        child: const Icon(Icons.close, size: 13, color: Colors.black38))),
                  ]),
                ]),
                const SizedBox(height: 8),
                Container(height: 0.5, color: Colors.black12),
                const SizedBox(height: 8),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  const Text('total bruto', style: TextStyle(fontSize: 11, color: Colors.black45)),
                  Text(_fmt(total), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500,
                      color: bateu ? const Color(0xFF1D9E75) : const Color(0xFF993C1D))),
                ]),
                if (abast > 0) ...[
                  const SizedBox(height: 3),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    const Text('abastecimento', style: TextStyle(fontSize: 11, color: Colors.black45)),
                    Text('-${_fmt(abast)}', style: const TextStyle(fontSize: 12, color: Color(0xFF993C1D))),
                  ]),
                  const SizedBox(height: 3),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    const Text('líquido', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Colors.black54)),
                    Text(_fmt(liquido), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF185FA5))),
                  ]),
                ],
                const SizedBox(height: 3),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  const Text('meta do dia', style: TextStyle(fontSize: 11, color: Colors.black45)),
                  Text(_fmt(meta), style: const TextStyle(fontSize: 12, color: Colors.black87)),
                ]),
                const SizedBox(height: 3),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  const Text('viagens · km · horas', style: TextStyle(fontSize: 11, color: Colors.black45)),
                  Text('$viagens${km > 0 ? ' · ${km.toStringAsFixed(0)}km' : ''}${horas > 0 ? ' · ${_fmtH(horas)}' : ''}',
                      style: const TextStyle(fontSize: 12, color: Colors.black87)),
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
                    backgroundColor: const Color(0xFFEEEEEE),
                    color: bateu ? const Color(0xFF1D9E75) : const Color(0xFF993C1D))),
                const SizedBox(height: 4),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text('${(pctDia * 100).toStringAsFixed(0)}%',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500,
                          color: bateu ? const Color(0xFF1D9E75) : const Color(0xFF993C1D))),
                  Text(_fmt(meta), style: const TextStyle(fontSize: 10, color: Colors.black38)),
                ]),
              ])));
        }),
      ]),
    );
  }

  Widget _mini(String label, String val, Color color) => Expanded(
    child: Container(padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: const Color(0xFFEEEEEA), borderRadius: BorderRadius.circular(10)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 9, color: Colors.black45)),
        const SizedBox(height: 2),
        Text(val, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: color)),
      ])));

  Widget _mediaCard(String label, String val) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: BoxDecoration(color: const Color(0xFFF5F5F0), borderRadius: BorderRadius.circular(8)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontSize: 9, color: Colors.black45)),
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
  // filtro
  DateTime? _inicio;
  DateTime? _fim;
  DateTime _calMes = DateTime.now();
  bool _showCal = false;
  String _quickSel = '30';

  @override
  void initState() {
    super.initState();
    _aplicarQuick('30');
  }

  void _aplicarQuick(String q) {
    final now = DateTime.now();
    setState(() {
      _quickSel = q;
      _fim = now;
      if (q == 'hoje') { _inicio = DateTime(now.year, now.month, now.day); }
      else if (q == 'mes') { _inicio = DateTime(now.year, now.month, 1); }
      else { final days = int.tryParse(q) ?? 30; _inicio = now.subtract(Duration(days: days)); }
    });
  }

  List<Map<String, dynamic>> get _diasFiltrados {
    if (_inicio == null || _fim == null) return widget.dias;
    return widget.dias.where((d) {
      try {
        final iso = d['dataISO'] as String?;
        if (iso != null) {
          final dt = DateTime.parse(iso);
          return !dt.isBefore(_inicio!) && !dt.isAfter(_fim!.add(const Duration(days: 1)));
        }
        // fallback: parse dd/mm/yyyy
        final parts = (d['data'] as String).split('/');
        final dt = DateTime(int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
        return !dt.isBefore(_inicio!) && !dt.isAfter(_fim!.add(const Duration(days: 1)));
      } catch (_) { return true; }
    }).toList();
  }

  String _fmt(double v) => 'R\$ ${v.toStringAsFixed(2).replaceAll('.', ',')}';
  String _fmtH(double h) { final hh = h.floor(); final mm = ((h-hh)*60).round(); return mm > 0 ? '${hh}h${mm.toString().padLeft(2,'0')}' : '${hh}h'; }
  String _fmtDate(DateTime d) => '${d.day.toString().padLeft(2,'0')}/${d.month.toString().padLeft(2,'0')}/${d.year}';

  @override
  Widget build(BuildContext context) {
    final dias = _diasFiltrados;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: Column(children: [
        // Botão filtro
        GestureDetector(
          onTap: () => setState(() => _showCal = !_showCal),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: _showCal ? const Color(0xFFE1F5EE) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _showCal ? const Color(0xFF5DCAA5) : Colors.black12, width: 0.5),
            ),
            child: Row(children: [
              Icon(Icons.calendar_month_outlined, size: 16,
                  color: _showCal ? const Color(0xFF085041) : Colors.black54),
              const SizedBox(width: 8),
              Expanded(child: Text(
                _inicio != null && _fim != null
                  ? '${_fmtDate(_inicio!)}  →  ${_fmtDate(_fim!)}'
                  : 'Selecionar período',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500,
                    color: _showCal ? const Color(0xFF085041) : Colors.black87),
              )),
              Icon(_showCal ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                  size: 18, color: Colors.black38),
            ]),
          ),
        ),
        const SizedBox(height: 8),

        // Atalhos rápidos (sempre visíveis)
        SingleChildScrollView(scrollDirection: Axis.horizontal,
          child: Row(children: [
            for (final q in [('hoje','Hoje'),('7','7 dias'),('30','30 dias'),('60','60 dias'),('90','90 dias'),('mes','Este mês')])
              Padding(padding: const EdgeInsets.only(right: 6),
                child: GestureDetector(onTap: () => _aplicarQuick(q.$1),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _quickSel == q.$1 ? const Color(0xFF1D9E75) : const Color(0xFFEEEEEE),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(q.$2, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500,
                        color: _quickSel == q.$1 ? Colors.white : Colors.black54)),
                  ))),
          ])),
        const SizedBox(height: 8),

        // Calendário expansível
        if (_showCal) ...[
          _CalendarioWidget(
            mes: _calMes,
            inicio: _inicio,
            fim: _fim,
            onMesChanged: (m) => setState(() => _calMes = m),
            onRangeChanged: (ini, fim) => setState(() { _inicio = ini; _fim = fim; _quickSel = ''; }),
          ),
          const SizedBox(height: 8),
        ],

        Builder(builder: (context) {
          if (dias.isEmpty) {
            return Container(padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.black12, width: 0.5)),
              child: const Center(child: Text('Nenhum dia no período selecionado.',
                  style: TextStyle(color: Colors.black38))));
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

          // Card total
          Container(width: double.infinity, padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.black12, width: 0.5)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Total ganho (${dias.length} dias)', style: const TextStyle(fontSize: 12, color: Colors.black45)),
              const SizedBox(height: 4),
              Text(_fmt(totalGanho), style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w500, color: Color(0xFF1D9E75))),
              if (totalAbast > 0) ...[
                const SizedBox(height: 4),
                Row(children: [
                  Text('abastec.: -${_fmt(totalAbast)}', style: const TextStyle(fontSize: 12, color: Color(0xFF993C1D))),
                  const SizedBox(width: 12),
                  Text('líquido: ${_fmt(liquido)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF185FA5))),
                ]),
              ],
            ])),
          const SizedBox(height: 8),

          // Grid stats
          GridView.count(crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 8, mainAxisSpacing: 8, childAspectRatio: 2.2,
            children: [
              _numCard('Dias trabalhados', '${dias.length}', Colors.black87),
              _numCard('Metas batidas', '$batidas de ${dias.length}', const Color(0xFF1D9E75)),
              _numCard('Aproveitamento', '$pct%', pct >= 70 ? const Color(0xFF1D9E75) : const Color(0xFFBA7517)),
              _numCard('Total viagens', '$totalViagens', Colors.black87),
              _numCard('Km rodados', '${totalKm.toStringAsFixed(0)} km', const Color(0xFF185FA5)),
              _numCard('Horas trabalhadas', _fmtH(totalHoras), Colors.black87),
            ]),
          const SizedBox(height: 8),

          // Médias
          Container(padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.black12, width: 0.5)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Médias do período', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.black54)),
              const SizedBox(height: 12),
              _mediaRow('Ganho por dia', _fmt(mediaDia)),
              _mediaRow('Ganho por viagem', _fmt(mediaVia)),
              if (totalHoras > 0) _mediaRow('Ganho por hora', 'R\$ ${mediaH.toStringAsFixed(2).replaceAll('.', ',')}/h'),
              if (totalKm > 0) _mediaRow('Ganho por km', 'R\$ ${mediaKm.toStringAsFixed(2).replaceAll('.', ',')}/km'),
              if (totalAbast > 0) _mediaRow('Líquido por dia', _fmt(liquido / dias.length)),
              if (totalViagens > 0) _mediaRow('Viagens por dia', (totalViagens / dias.length).toStringAsFixed(1)),
            ])),
          ]);
        }),
      ]),
    );
  }

  Widget _numCard(String label, String val, Color color) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: const Color(0xFFEEEEEA), borderRadius: BorderRadius.circular(12)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontSize: 10, color: Colors.black45)),
      const SizedBox(height: 4),
      Text(val, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: color)),
    ]));

  Widget _mediaRow(String label, String val) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: const TextStyle(fontSize: 13, color: Colors.black54)),
      Text(val, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.black87)),
    ]));
}

// ─── CALENDÁRIO ───────────────────────────────────────────────────────────────

class _CalendarioWidget extends StatefulWidget {
  final DateTime mes;
  final DateTime? inicio, fim;
  final Function(DateTime) onMesChanged;
  final Function(DateTime, DateTime) onRangeChanged;
  const _CalendarioWidget({required this.mes, this.inicio, this.fim,
    required this.onMesChanged, required this.onRangeChanged});
  @override State<_CalendarioWidget> createState() => _CalendarioWidgetState();
}

class _CalendarioWidgetState extends State<_CalendarioWidget> {
  DateTime? _tapInicio;

  void _tapDia(DateTime dia) {
    if (_tapInicio == null || (widget.inicio != null && widget.fim != null)) {
      setState(() => _tapInicio = dia);
    } else {
      final ini = _tapInicio!.isBefore(dia) ? _tapInicio! : dia;
      final fim = _tapInicio!.isBefore(dia) ? dia : _tapInicio!;
      setState(() => _tapInicio = null);
      widget.onRangeChanged(ini, fim);
    }
  }

  bool _isInRange(DateTime d) {
    final ini = _tapInicio ?? widget.inicio;
    final fim = widget.fim;
    if (ini == null) return false;
    if (_tapInicio != null) return d == ini;
    if (fim == null) return d == ini;
    return !d.isBefore(ini) && !d.isAfter(fim);
  }

  bool _isStart(DateTime d) => (_tapInicio ?? widget.inicio)?.year == d.year &&
      (_tapInicio ?? widget.inicio)?.month == d.month &&
      (_tapInicio ?? widget.inicio)?.day == d.day;
  bool _isEnd(DateTime d) => widget.fim?.year == d.year && widget.fim?.month == d.month && widget.fim?.day == d.day && _tapInicio == null;
  bool _isToday(DateTime d) { final n = DateTime.now(); return d.year == n.year && d.month == n.month && d.day == n.day; }

  @override
  Widget build(BuildContext context) {
    final mes = widget.mes;
    final firstDay = DateTime(mes.year, mes.month, 1);
    final daysInMonth = DateTime(mes.year, mes.month + 1, 0).day;
    final startWeekday = firstDay.weekday % 7; // 0=dom
    final meses = ['Janeiro','Fevereiro','Março','Abril','Maio','Junho','Julho','Agosto','Setembro','Outubro','Novembro','Dezembro'];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.black12, width: 0.5)),
      child: Column(children: [
        // Header do mês
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          GestureDetector(onTap: () => widget.onMesChanged(DateTime(mes.year, mes.month - 1)),
            child: Container(padding: const EdgeInsets.all(6),
              child: const Icon(Icons.chevron_left, size: 20, color: Colors.black54))),
          Text('${meses[mes.month - 1]} ${mes.year}',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
          GestureDetector(onTap: () => widget.onMesChanged(DateTime(mes.year, mes.month + 1)),
            child: Container(padding: const EdgeInsets.all(6),
              child: const Icon(Icons.chevron_right, size: 20, color: Colors.black54))),
        ]),
        const SizedBox(height: 10),

        // Nomes dos dias
        Row(children: ['D','S','T','Q','Q','S','S'].map((d) => Expanded(
          child: Center(child: Text(d, style: const TextStyle(fontSize: 11, color: Colors.black38, fontWeight: FontWeight.w500))))).toList()),
        const SizedBox(height: 4),

        // Grid dos dias
        GridView.builder(
          shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7, childAspectRatio: 1),
          itemCount: startWeekday + daysInMonth,
          itemBuilder: (_, i) {
            if (i < startWeekday) return const SizedBox();
            final dia = DateTime(mes.year, mes.month, i - startWeekday + 1);
            final inRange = _isInRange(dia);
            final isStart = _isStart(dia);
            final isEnd = _isEnd(dia);
            final isToday = _isToday(dia);

            Color bg = Colors.transparent;
            Color fg = Colors.black87;
            BorderRadius br = BorderRadius.circular(6);

            if (isStart) { bg = const Color(0xFF1D9E75); fg = Colors.white; br = const BorderRadius.only(topLeft: Radius.circular(99), bottomLeft: Radius.circular(99)); }
            else if (isEnd) { bg = const Color(0xFF1D9E75); fg = Colors.white; br = const BorderRadius.only(topRight: Radius.circular(99), bottomRight: Radius.circular(99)); }
            else if (inRange) { bg = const Color(0xFFE1F5EE); fg = const Color(0xFF085041); br = BorderRadius.zero; }
            else if (isToday) { bg = const Color(0xFF9FE1CB); fg = const Color(0xFF085041); br = BorderRadius.circular(99); }

            return GestureDetector(
              onTap: () => _tapDia(dia),
              child: Container(
                decoration: BoxDecoration(color: bg, borderRadius: br),
                child: Center(child: Text('${dia.day}',
                    style: TextStyle(fontSize: 11, fontWeight: (isStart || isEnd) ? FontWeight.w600 : FontWeight.normal, color: fg)))),
            );
          }),
        const SizedBox(height: 6),
        if (_tapInicio != null)
          Text('Toque no dia final do período', style: TextStyle(fontSize: 11, color: Colors.black38, fontStyle: FontStyle.italic)),
      ]),
    );
  }
}

// ─── OVERLAY ──────────────────────────────────────────────────────────────────

class OverlayWidget extends StatefulWidget {
  const OverlayWidget({super.key});
  @override State<OverlayWidget> createState() => _OverlayWidgetState();
}

class _OverlayWidgetState extends State<OverlayWidget> {
  double _atual = 0, _meta = 500; int _viagens = 0;
  @override
  void initState() {
    super.initState();
    FlutterOverlayWindow.overlayListener.listen((data) {
      if (data is Map && mounted) setState(() {
        _atual = (data['atual'] as num?)?.toDouble() ?? _atual;
        _meta = (data['meta'] as num?)?.toDouble() ?? _meta;
        _viagens = (data['viagens'] as num?)?.toInt() ?? _viagens;
      });
    });
  }
  String _fmt(double v) => 'R\$ ${v.toStringAsFixed(2).replaceAll('.', ',')}';
  double get _pct => _meta > 0 ? (_atual / _meta).clamp(0, 1) : 0;
  double get _falta => (_meta - _atual).clamp(0, double.infinity);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(debugShowCheckedModeBanner: false,
      home: Scaffold(backgroundColor: Colors.transparent,
        body: SafeArea(child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 12, offset: const Offset(0, 3))]),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              Text(_fmt(_atual), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Color(0xFF1D9E75))),
              const SizedBox(width: 8),
              Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(color: const Color(0xFFE1F5EE), borderRadius: BorderRadius.circular(99)),
                child: Text('$_viagens viagens', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: Color(0xFF0F6E56)))),
              const Spacer(),
              Text(_falta <= 0 ? 'Meta atingida!' : 'falta ${_fmt(_falta)}',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500,
                      color: _falta <= 0 ? const Color(0xFF1D9E75) : const Color(0xFF993C1D))),
              const SizedBox(width: 8),
              GestureDetector(onTap: () async => await FlutterOverlayWindow.closeOverlay(),
                child: Container(width: 24, height: 24,
                  decoration: BoxDecoration(color: const Color(0xFFF1EFE8), borderRadius: BorderRadius.circular(99)),
                  child: const Icon(Icons.close, size: 14, color: Colors.black45))),
            ]),
            const SizedBox(height: 8),
            ClipRRect(borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(value: _pct, minHeight: 8,
                  backgroundColor: const Color(0xFFEEEEEE), color: const Color(0xFF1D9E75))),
            const SizedBox(height: 4),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('${(_pct * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(fontSize: 10, color: Color(0xFF1D9E75), fontWeight: FontWeight.w500)),
              Text('Meta: ${_fmt(_meta)}', style: const TextStyle(fontSize: 10, color: Colors.black38)),
            ]),
          ]),
        )),
      ));
  }
}
