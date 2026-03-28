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
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Meta Viagem',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: const Color(0xFF1D9E75), useMaterial3: true),
      home: const RootPage(),
    );
  }
}

// ─── ROOT com abas ────────────────────────────────────────────────────────────

class RootPage extends StatefulWidget {
  const RootPage({super.key});
  @override
  State<RootPage> createState() => _RootPageState();
}

class _RootPageState extends State<RootPage> {
  int _tab = 0;

  // Estado compartilhado entre abas
  double _atual = 0;
  double _meta = 500;
  List<Map<String, dynamic>> _viagens = [];
  List<Map<String, dynamic>> _dias = [];
  bool _overlayActive = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _atual = prefs.getDouble('atual') ?? 0;
      _meta = prefs.getDouble('meta') ?? 500;
      final rv = prefs.getString('viagens');
      if (rv != null) _viagens = List<Map<String, dynamic>>.from(jsonDecode(rv));
      final rd = prefs.getString('dias');
      if (rd != null) _dias = List<Map<String, dynamic>>.from(jsonDecode(rd));
    });
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('atual', _atual);
    await prefs.setDouble('meta', _meta);
    await prefs.setString('viagens', jsonEncode(_viagens));
    await prefs.setString('dias', jsonEncode(_dias));
    try {
      FlutterOverlayWindow.shareData({'atual': _atual, 'meta': _meta, 'viagens': _viagens.length});
    } catch (_) {}
  }

  void _onHojeChanged(double atual, double meta, List<Map<String, dynamic>> viagens) {
    setState(() { _atual = atual; _meta = meta; _viagens = viagens; });
    _save();
  }

  void _onEncerrarDia(Map<String, dynamic> dia) {
    setState(() {
      _dias.insert(0, dia);
      _atual = 0;
      _viagens = [];
    });
    _save();
  }

  Future<void> _toggleOverlay() async {
    try {
      final granted = await FlutterOverlayWindow.isPermissionGranted();
      if (!granted) {
        await FlutterOverlayWindow.requestPermission();
        return;
      }
      final active = await FlutterOverlayWindow.isActive();
      if (active) {
        await FlutterOverlayWindow.closeOverlay();
        setState(() => _overlayActive = false);
      } else {
        await FlutterOverlayWindow.showOverlay(
          enableDrag: true,
          overlayTitle: 'Meta Viagem',
          overlayContent: 'Widget ativo',
          flag: OverlayFlag.focusPointer,
          visibility: NotificationVisibility.visibilityPublic,
          positionGravity: PositionGravity.auto,
          width: WindowSize.matchParent,
          height: 110,
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
        actions: [
          IconButton(
            icon: Icon(_overlayActive ? Icons.picture_in_picture : Icons.picture_in_picture_outlined,
                color: _overlayActive ? const Color(0xFF1D9E75) : Colors.black45),
            onPressed: _toggleOverlay,
          ),
        ],
      ),
      body: Column(children: [
        // Tabs
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            decoration: BoxDecoration(color: const Color(0xFFE8E8E2), borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.all(3),
            child: Row(children: List.generate(tabs.length, (i) => Expanded(
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
          ),
        ),
        const SizedBox(height: 12),
        Expanded(child: _tab == 0
          ? HojeTab(atual: _atual, meta: _meta, viagens: _viagens,
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
  final double atual, meta;
  final List<Map<String, dynamic>> viagens;
  final Function(double, double, List<Map<String, dynamic>>) onChanged;
  final Function(Map<String, dynamic>) onEncerrarDia;
  const HojeTab({super.key, required this.atual, required this.meta,
    required this.viagens, required this.onChanged, required this.onEncerrarDia});
  @override
  State<HojeTab> createState() => _HojeTabState();
}

class _HojeTabState extends State<HojeTab> {
  late double _atual;
  late double _meta;
  late List<Map<String, dynamic>> _viagens;
  final _corridaCtrl = TextEditingController();
  final _metaCtrl = TextEditingController();
  final _kmCtrl = TextEditingController();
  final _horasCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _atual = widget.atual;
    _meta = widget.meta;
    _viagens = List.from(widget.viagens);
  }

  @override
  void didUpdateWidget(HojeTab old) {
    super.didUpdateWidget(old);
    if (old.atual != widget.atual) _atual = widget.atual;
    if (old.meta != widget.meta) _meta = widget.meta;
    if (old.viagens != widget.viagens) _viagens = List.from(widget.viagens);
  }

  void _notify() => widget.onChanged(_atual, _meta, _viagens);

  void _addViagem() {
    final val = double.tryParse(_corridaCtrl.text.replaceAll(',', '.'));
    if (val == null || val <= 0) return;
    setState(() {
      _atual += val;
      _viagens.add({'val': val, 'hora': TimeOfDay.now().format(context)});
    });
    _corridaCtrl.clear();
    _notify();
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
          _notify();
          Navigator.pop(context);
        }, child: const Text('Excluir', style: TextStyle(color: Colors.red))),
      ],
    ));
  }

  void _setMeta() {
    final val = double.tryParse(_metaCtrl.text.replaceAll(',', '.'));
    if (val == null || val <= 0) return;
    setState(() => _meta = val);
    _metaCtrl.clear();
    _notify();
    _showSnack('Meta atualizada para ${_fmt(val)}');
  }

  void _zerar() {
    showDialog(context: context, builder: (_) => AlertDialog(
      title: const Text('Zerar tudo?'),
      content: const Text('Apaga o saldo e todas as viagens de hoje.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        TextButton(onPressed: () {
          setState(() { _atual = 0; _viagens = []; });
          _notify();
          Navigator.pop(context);
        }, child: const Text('Zerar', style: TextStyle(color: Colors.red))),
      ],
    ));
  }

  void _encerrarDia() {
    final kmText = _kmCtrl.text.trim();
    final horasText = _horasCtrl.text.trim();
    final km = double.tryParse(kmText.replaceAll(',', '.')) ?? 0;

    // Parse horas: aceita "8", "8.5", "8h30", "8:30"
    double horas = 0;
    if (horasText.isNotEmpty) {
      final clean = horasText.replaceAll('h', ':').replaceAll(',', '.');
      if (clean.contains(':')) {
        final parts = clean.split(':');
        final h = double.tryParse(parts[0]) ?? 0;
        final m = double.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0;
        horas = h + m / 60;
      } else {
        horas = double.tryParse(clean) ?? 0;
      }
    }

    if (_viagens.isEmpty) { _showSnack('Adicione pelo menos uma viagem antes de encerrar.'); return; }

    showDialog(context: context, builder: (_) => AlertDialog(
      title: const Text('Encerrar o dia?'),
      content: Text('O dia será salvo no Diário com ${_fmt(_atual)} em ${_viagens.length} viagens.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        TextButton(onPressed: () {
          final now = DateTime.now();
          final dia = {
            'data': '${now.day.toString().padLeft(2,'0')}/${now.month.toString().padLeft(2,'0')}/${now.year}',
            'semana': _diaSemana(now.weekday),
            'total': _atual,
            'meta': _meta,
            'viagens': _viagens.length,
            'km': km,
            'horas': horas,
            'bateu': _atual >= _meta,
          };
          widget.onEncerrarDia(dia);
          _kmCtrl.clear();
          _horasCtrl.clear();
          Navigator.pop(context);
          _showSnack('Dia encerrado e salvo no Diário!');
        }, child: const Text('Encerrar', style: TextStyle(color: Color(0xFF1D9E75)))),
      ],
    ));
  }

  String _diaSemana(int w) => ['Segunda','Terça','Quarta','Quinta','Sexta','Sábado','Domingo'][w-1];
  String _fmt(double v) => 'R\$ ${v.toStringAsFixed(2).replaceAll('.', ',')}';
  double get _pct => _meta > 0 ? (_atual / _meta).clamp(0, 1) : 0;
  double get _falta => (_meta - _atual).clamp(0, double.infinity);
  double get _media => _viagens.isEmpty ? 0 : _atual / _viagens.length;

  void _showSnack(String msg) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(msg), duration: const Duration(seconds: 3)));

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(children: [
        // Stats
        Row(children: [
          _statCard('Saldo atual', _fmt(_atual), const Color(0xFF1D9E75)),
          const SizedBox(width: 8),
          _statCard('Viagens', '${_viagens.length}', Colors.black87),
          const SizedBox(width: 8),
          _statCard('Média', _fmt(_media), Colors.black54),
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
        // Inputs viagem e meta
        _card(Column(children: [
          Row(children: [
            Expanded(child: _inputField(_corridaCtrl, 'Valor da viagem (R\$)', '18.50')),
            const SizedBox(width: 8),
            Expanded(child: _inputField(_metaCtrl, 'Meta (R\$)', '500')),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _btn('+ Viagem', const Color(0xFF1D9E75), Colors.white, _addViagem)),
            const SizedBox(width: 6),
            Expanded(child: _btn('Salvar meta', Colors.white, Colors.black87, _setMeta, border: Colors.black26)),
            const SizedBox(width: 6),
            Expanded(child: _btn('Zerar', Colors.white, const Color(0xFF993C1D), _zerar, border: const Color(0xFFD85A30))),
          ]),
        ])),
        const SizedBox(height: 12),
        // Encerrar dia
        _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Encerrar o dia', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.black54)),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _inputField(_kmCtrl, 'Km rodados', '150')),
            const SizedBox(width: 8),
            Expanded(child: _inputField(_horasCtrl, 'Horas trabalhadas', '8h30')),
          ]),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: _encerrarDia,
            child: Container(
              width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(color: const Color(0xFF1D9E75), borderRadius: BorderRadius.circular(10)),
              child: const Center(child: Text('+ Encerrar dia e salvar',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.white))),
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
            const Text('Viagens de hoje', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.black54)),
            const SizedBox(height: 10),
            ..._viagens.reversed.take(30).toList().asMap().entries.map((e) {
              final origIdx = _viagens.length - 1 - e.key;
              final v = e.value;
              return Padding(padding: const EdgeInsets.only(bottom: 6),
                child: Row(children: [
                  Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: const Color(0xFF9FE1CB), borderRadius: BorderRadius.circular(99)),
                    child: Text('#${origIdx + 1}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Color(0xFF085041)))),
                  const SizedBox(width: 8),
                  Text(v['hora'] ?? '', style: const TextStyle(fontSize: 11, color: Colors.black38)),
                  const Spacer(),
                  Text('+${_fmt((v['val'] as num).toDouble())}',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF1D9E75))),
                  const SizedBox(width: 8),
                  GestureDetector(onTap: () => _removeViagem(origIdx),
                    child: Container(padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(color: const Color(0xFFFAECE7), borderRadius: BorderRadius.circular(6)),
                      child: const Icon(Icons.close, size: 14, color: Color(0xFF993C1D)))),
                ]));
            }),
          ])),
      ]),
    );
  }

  Widget _card(Widget child) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black12, width: 0.5)),
    child: child);

  Widget _statCard(String label, String value, Color color) => Expanded(
    child: Container(padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: const Color(0xFFEEEEEE), borderRadius: BorderRadius.circular(10)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.black45)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: color)),
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
  String _fmtHoras(double h) {
    final hh = h.floor();
    final mm = ((h - hh) * 60).round();
    return mm > 0 ? '${hh}h${mm.toString().padLeft(2,'0')}' : '${hh}h';
  }

  @override
  Widget build(BuildContext context) {
    if (dias.isEmpty) {
      return const Center(child: Text('Nenhum dia registrado ainda.\nEncerre o primeiro dia na aba Hoje!',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.black38, fontSize: 14)));
    }

    // Resumo do mês
    final batidas = dias.where((d) => d['bateu'] == true).length;
    final pct = dias.isEmpty ? 0 : (batidas / dias.length * 100).round();
    final kmTotal = dias.fold<double>(0, (s, d) => s + (d['km'] as num? ?? 0).toDouble());

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(children: [
        // Stats do mês
        Row(children: [
          _miniStat('dias', '${dias.length}', Colors.black87),
          const SizedBox(width: 6),
          _miniStat('metas batidas', '$batidas', const Color(0xFF1D9E75)),
          const SizedBox(width: 6),
          _miniStat('aproveit.', '$pct%', const Color(0xFFBA7517)),
          const SizedBox(width: 6),
          _miniStat('km total', '${kmTotal.toStringAsFixed(0)}', const Color(0xFF185FA5)),
        ]),
        const SizedBox(height: 14),
        ...dias.asMap().entries.map((e) {
          final i = e.key;
          final d = e.value;
          final total = (d['total'] as num).toDouble();
          final meta = (d['meta'] as num).toDouble();
          final km = (d['km'] as num? ?? 0).toDouble();
          final horas = (d['horas'] as num? ?? 0).toDouble();
          final viagens = d['viagens'] as int? ?? 0;
          final bateu = d['bateu'] as bool? ?? false;
          final pctDia = meta > 0 ? (total / meta).clamp(0.0, 1.0) : 0.0;
          final ganhoHora = horas > 0 ? total / horas : 0.0;
          final ganhoKm = km > 0 ? total / km : 0.0;

          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.black12, width: 0.5)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // Header
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(i == 0 ? 'Hoje, ${d['data']}' : d['data'] ?? '',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
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
                // Valores principais
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  const Text('total ganho', style: TextStyle(fontSize: 11, color: Colors.black45)),
                  Text(_fmt(total), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500,
                      color: bateu ? const Color(0xFF1D9E75) : const Color(0xFF993C1D))),
                ]),
                const SizedBox(height: 4),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  const Text('meta do dia', style: TextStyle(fontSize: 11, color: Colors.black45)),
                  Text(_fmt(meta), style: const TextStyle(fontSize: 12, color: Colors.black87)),
                ]),
                const SizedBox(height: 4),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  const Text('viagens · km · horas', style: TextStyle(fontSize: 11, color: Colors.black45)),
                  Text(
                    '$viagens${km > 0 ? ' · ${km.toStringAsFixed(0)}km' : ''}${horas > 0 ? ' · ${_fmtHoras(horas)}' : ''}',
                    style: const TextStyle(fontSize: 12, color: Colors.black87)),
                ]),
                // Médias (só mostra se tiver km ou horas)
                if (km > 0 || horas > 0) ...[
                  const SizedBox(height: 10),
                  Row(children: [
                    if (horas > 0) Expanded(child: _mediaCard('ganho por hora', 'R\$ ${ganhoHora.toStringAsFixed(2).replaceAll('.', ',')}/h')),
                    if (horas > 0 && km > 0) const SizedBox(width: 8),
                    if (km > 0) Expanded(child: _mediaCard('ganho por km', 'R\$ ${ganhoKm.toStringAsFixed(2).replaceAll('.', ',')}/km')),
                  ]),
                ],
                const SizedBox(height: 10),
                // Barra de progresso
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
              ]),
            ),
          );
        }),
      ]),
    );
  }

  Widget _miniStat(String label, String val, Color color) => Expanded(
    child: Container(padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: const Color(0xFFEEEEEA), borderRadius: BorderRadius.circular(10)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 9, color: Colors.black45)),
        const SizedBox(height: 2),
        Text(val, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: color)),
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

class ResumoTab extends StatelessWidget {
  final List<Map<String, dynamic>> dias;
  const ResumoTab({super.key, required this.dias});

  String _fmt(double v) => 'R\$ ${v.toStringAsFixed(2).replaceAll('.', ',')}';

  @override
  Widget build(BuildContext context) {
    if (dias.isEmpty) {
      return const Center(child: Text('Nenhum dado ainda.\nEncerre pelo menos um dia para ver o resumo!',
          textAlign: TextAlign.center, style: TextStyle(color: Colors.black38, fontSize: 14)));
    }

    final totalGanho = dias.fold<double>(0, (s, d) => s + (d['total'] as num).toDouble());
    final totalKm = dias.fold<double>(0, (s, d) => s + (d['km'] as num? ?? 0).toDouble());
    final totalHoras = dias.fold<double>(0, (s, d) => s + (d['horas'] as num? ?? 0).toDouble());
    final totalViagens = dias.fold<int>(0, (s, d) => s + (d['viagens'] as int? ?? 0));
    final batidas = dias.where((d) => d['bateu'] == true).length;
    final mediaDia = dias.isEmpty ? 0.0 : totalGanho / dias.length;
    final mediaHora = totalHoras > 0 ? totalGanho / totalHoras : 0.0;
    final mediaKm = totalKm > 0 ? totalGanho / totalKm : 0.0;
    final mediaViagem = totalViagens > 0 ? totalGanho / totalViagens : 0.0;
    final pct = dias.isEmpty ? 0 : (batidas / dias.length * 100).round();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: Column(children: [
        _bigCard('Total ganho', _fmt(totalGanho), const Color(0xFF1D9E75)),
        const SizedBox(height: 10),
        Row(children: [
          _numCard('Dias trabalhados', '${dias.length}', Colors.black87),
          const SizedBox(width: 8),
          _numCard('Metas batidas', '$batidas de ${dias.length}', const Color(0xFF1D9E75)),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          _numCard('Aproveitamento', '$pct%', pct >= 70 ? const Color(0xFF1D9E75) : const Color(0xFFBA7517)),
          const SizedBox(width: 8),
          _numCard('Total viagens', '$totalViagens', Colors.black87),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          _numCard('Km total', '${totalKm.toStringAsFixed(0)} km', const Color(0xFF185FA5)),
          const SizedBox(width: 8),
          _numCard('Horas total', _fmtH(totalHoras), Colors.black87),
        ]),
        const SizedBox(height: 14),
        Container(width: double.infinity, padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.black12, width: 0.5)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Médias', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.black54)),
            const SizedBox(height: 12),
            _mediaRow('Ganho por dia', _fmt(mediaDia)),
            _mediaRow('Ganho por viagem', _fmt(mediaViagem)),
            if (totalHoras > 0) _mediaRow('Ganho por hora', 'R\$ ${mediaHora.toStringAsFixed(2).replaceAll('.', ',')}/h'),
            if (totalKm > 0) _mediaRow('Ganho por km', 'R\$ ${mediaKm.toStringAsFixed(2).replaceAll('.', ',')}/km'),
            if (totalViagens > 0 && dias.isNotEmpty)
              _mediaRow('Viagens por dia', (totalViagens / dias.length).toStringAsFixed(1)),
          ])),
      ]),
    );
  }

  String _fmtH(double h) {
    final hh = h.floor(); final mm = ((h - hh) * 60).round();
    return mm > 0 ? '${hh}h${mm.toString().padLeft(2,'0')}' : '${hh}h';
  }

  Widget _bigCard(String label, String val, Color color) => Container(
    width: double.infinity, padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black12, width: 0.5)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontSize: 13, color: Colors.black45)),
      const SizedBox(height: 4),
      Text(val, style: TextStyle(fontSize: 28, fontWeight: FontWeight.w500, color: color)),
    ]));

  Widget _numCard(String label, String val, Color color) => Expanded(
    child: Container(padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: const Color(0xFFEEEEEA), borderRadius: BorderRadius.circular(12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.black45)),
        const SizedBox(height: 4),
        Text(val, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: color)),
      ])));

  Widget _mediaRow(String label, String val) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: const TextStyle(fontSize: 13, color: Colors.black54)),
      Text(val, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.black87)),
    ]));
}

// ─── OVERLAY ──────────────────────────────────────────────────────────────────

class OverlayWidget extends StatefulWidget {
  const OverlayWidget({super.key});
  @override
  State<OverlayWidget> createState() => _OverlayWidgetState();
}

class _OverlayWidgetState extends State<OverlayWidget> {
  double _atual = 0, _meta = 500;
  int _viagens = 0;

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
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Container(
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
          ),
        ),
      ),
    );
  }
}
