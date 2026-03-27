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
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  double _atual = 0;
  double _meta = 500;
  List<Map<String, dynamic>> _viagens = [];
  final _corridaCtrl = TextEditingController();
  final _metaCtrl = TextEditingController();
  bool _overlayActive = false;

  @override
  void initState() {
    super.initState();
    _load();
    _checkOverlay();
  }

  Future<void> _checkOverlay() async {
    final active = await FlutterOverlayWindow.isActive();
    if (mounted) setState(() => _overlayActive = active);
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _atual = prefs.getDouble('atual') ?? 0;
      _meta = prefs.getDouble('meta') ?? 500;
      final raw = prefs.getString('viagens');
      if (raw != null) _viagens = List<Map<String, dynamic>>.from(jsonDecode(raw));
    });
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('atual', _atual);
    await prefs.setDouble('meta', _meta);
    await prefs.setString('viagens', jsonEncode(_viagens));
    try {
      FlutterOverlayWindow.shareData({'atual': _atual, 'meta': _meta, 'viagens': _viagens.length});
    } catch (_) {}
  }

  void _addViagem() {
    final val = double.tryParse(_corridaCtrl.text.replaceAll(',', '.'));
    if (val == null || val <= 0) return;
    setState(() {
      _atual += val;
      _viagens.add({'val': val, 'hora': TimeOfDay.now().format(context)});
    });
    _corridaCtrl.clear();
    _save();
    _showSnack('Viagem #${_viagens.length} adicionada! +${_fmt(val)}');
  }

  void _removeViagem(int originalIndex) {
    final val = (_viagens[originalIndex]['val'] as num).toDouble();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Excluir viagem?'),
        content: Text('Viagem #${originalIndex + 1} de ${_fmt(val)} será removida.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          TextButton(
            onPressed: () {
              setState(() {
                _atual = (_atual - val).clamp(0, double.infinity);
                _viagens.removeAt(originalIndex);
              });
              _save();
              Navigator.pop(context);
              _showSnack('Viagem removida.');
            },
            child: const Text('Excluir', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _setMeta() {
    final val = double.tryParse(_metaCtrl.text.replaceAll(',', '.'));
    if (val == null || val <= 0) return;
    setState(() => _meta = val);
    _metaCtrl.clear();
    _save();
    _showSnack('Meta atualizada para ${_fmt(val)}');
  }

  void _zerar() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Zerar tudo?'),
        content: const Text('Isso vai apagar o saldo e todas as viagens.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          TextButton(
            onPressed: () {
              setState(() { _atual = 0; _viagens = []; });
              _save();
              Navigator.pop(context);
              _showSnack('Zerado!');
            },
            child: const Text('Zerar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleOverlay() async {
    try {
      final granted = await FlutterOverlayWindow.isPermissionGranted();
      if (!granted) {
        await FlutterOverlayWindow.requestPermission();
        _showSnack('Ative a permissão "Exibir sobre outros apps" e tente de novo.');
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
          flag: OverlayFlag.defaultFlag,
          visibility: NotificationVisibility.visibilityPublic,
          positionGravity: PositionGravity.auto,
          width: 320,
          height: WindowSize.matchParent,
        );
        await Future.delayed(const Duration(milliseconds: 400));
        FlutterOverlayWindow.shareData({'atual': _atual, 'meta': _meta, 'viagens': _viagens.length});
        setState(() => _overlayActive = true);
      }
    } catch (e) {
      _showSnack('Erro: $e');
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 3)),
    );
  }

  String _fmt(double v) => 'R\$ ${v.toStringAsFixed(2).replaceAll('.', ',')}';
  double get _pct => _meta > 0 ? (_atual / _meta).clamp(0, 1) : 0;
  double get _falta => (_meta - _atual).clamp(0, double.infinity);
  double get _media => _viagens.isEmpty ? 0 : _atual / _viagens.length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F0),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5F5F0),
        title: const Text('Meta Viagem', style: TextStyle(fontWeight: FontWeight.w500)),
        actions: [
          IconButton(
            icon: Icon(_overlayActive ? Icons.picture_in_picture : Icons.picture_in_picture_outlined,
                color: const Color(0xFF1D9E75)),
            tooltip: _overlayActive ? 'Fechar flutuante' : 'Ativar flutuante',
            onPressed: _toggleOverlay,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          Row(children: [
            _statCard('Saldo atual', _fmt(_atual), const Color(0xFF1D9E75)),
            const SizedBox(width: 8),
            _statCard('Viagens', '${_viagens.length}', Colors.black87),
            const SizedBox(width: 8),
            _statCard('Média', _fmt(_media), Colors.black54),
          ]),
          const SizedBox(height: 16),
          _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('Meta: ${_fmt(_meta)}', style: const TextStyle(fontSize: 13, color: Colors.black54)),
              Text(
                _falta <= 0 ? 'Meta atingida!' : 'falta ${_fmt(_falta)}',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500,
                    color: _falta <= 0 ? const Color(0xFF1D9E75) : const Color(0xFF993C1D)),
              ),
            ]),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(value: _pct, minHeight: 10,
                  backgroundColor: const Color(0xFFEEEEEE), color: const Color(0xFF1D9E75)),
            ),
            const SizedBox(height: 6),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('${(_pct * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF1D9E75), fontWeight: FontWeight.w500)),
              Text(_fmt(_meta), style: const TextStyle(fontSize: 11, color: Colors.black45)),
            ]),
          ])),
          const SizedBox(height: 12),
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
          if (_viagens.isNotEmpty)
            _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Histórico de viagens',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.black54)),
              const SizedBox(height: 10),
              ..._viagens.reversed.take(30).toList().asMap().entries.map((e) {
                final reversedIdx = e.key;
                final originalIndex = _viagens.length - 1 - reversedIdx;
                final v = e.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: const Color(0xFF9FE1CB), borderRadius: BorderRadius.circular(99)),
                      child: Text('#${originalIndex + 1}',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Color(0xFF085041))),
                    ),
                    const SizedBox(width: 8),
                    Text(v['hora'] ?? '', style: const TextStyle(fontSize: 11, color: Colors.black38)),
                    const Spacer(),
                    Text('+${_fmt((v['val'] as num).toDouble())}',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF1D9E75))),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => _removeViagem(originalIndex),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                            color: const Color(0xFFFAECE7), borderRadius: BorderRadius.circular(6)),
                        child: const Icon(Icons.close, size: 14, color: Color(0xFF993C1D)),
                      ),
                    ),
                  ]),
                );
              }),
            ])),
        ]),
      ),
    );
  }

  Widget _card(Widget child) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white, borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.black12, width: 0.5),
    ),
    child: child,
  );

  Widget _statCard(String label, String value, Color color) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: const Color(0xFFEEEEEE), borderRadius: BorderRadius.circular(10)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.black45)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: color)),
      ]),
    ),
  );

  Widget _inputField(TextEditingController ctrl, String label, String hint) =>
    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontSize: 11, color: Colors.black54)),
      const SizedBox(height: 4),
      TextField(
        controller: ctrl,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          hintText: hint, hintStyle: const TextStyle(fontSize: 13),
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.black26, width: 0.5)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.black26, width: 0.5)),
        ),
      ),
    ]);

  Widget _btn(String label, Color bg, Color fg, VoidCallback onTap, {Color border = Colors.transparent}) =>
    GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8),
            border: Border.all(color: border, width: 0.5)),
        child: Center(child: Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: fg))),
      ),
    );
}

// ─── OVERLAY FLUTUANTE ───────────────────────────────────────────────────────

class OverlayWidget extends StatefulWidget {
  const OverlayWidget({super.key});
  @override
  State<OverlayWidget> createState() => _OverlayWidgetState();
}

class _OverlayWidgetState extends State<OverlayWidget> {
  double _atual = 0;
  double _meta = 500;
  int _viagens = 0;
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    FlutterOverlayWindow.overlayListener.listen((data) {
      if (data is Map && mounted) {
        setState(() {
          _atual = (data['atual'] as num?)?.toDouble() ?? _atual;
          _meta = (data['meta'] as num?)?.toDouble() ?? _meta;
          _viagens = (data['viagens'] as num?)?.toInt() ?? _viagens;
        });
      }
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
        body: GestureDetector(
          onTap: () => setState(() => _expanded = !_expanded),
          child: _expanded ? _expandedPanel() : _miniIcon(),
        ),
      ),
    );
  }

  Widget _miniIcon() => Align(
    alignment: Alignment.centerRight,
    child: Container(
      width: 60, height: 60,
      decoration: BoxDecoration(
        color: const Color(0xFF1D9E75), shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.25), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.directions_car, color: Colors.white, size: 18),
        Text('${(_pct * 100).toStringAsFixed(0)}%',
            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w500)),
      ]),
    ),
  );

  Widget _expandedPanel() => Align(
    alignment: Alignment.centerRight,
    child: Container(
      width: 300,
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.18), blurRadius: 16, offset: const Offset(0, 4))],
      ),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('Meta Viagem',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.black45, letterSpacing: 0.5)),
          GestureDetector(
            onTap: () => setState(() => _expanded = false),
            child: const Icon(Icons.keyboard_arrow_down, size: 18, color: Colors.black38),
          ),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Text(_fmt(_atual), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w500, color: Color(0xFF1D9E75))),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: const Color(0xFFE1F5EE), borderRadius: BorderRadius.circular(99)),
            child: Text('$_viagens viagens',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Color(0xFF0F6E56))),
          ),
        ]),
        const SizedBox(height: 4),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('Meta: ${_fmt(_meta)}', style: const TextStyle(fontSize: 12, color: Colors.black45)),
          Text(
            _falta <= 0 ? 'Atingida!' : 'falta ${_fmt(_falta)}',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500,
                color: _falta <= 0 ? const Color(0xFF1D9E75) : const Color(0xFF993C1D)),
          ),
        ]),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(value: _pct, minHeight: 8,
              backgroundColor: const Color(0xFFEEEEEE), color: const Color(0xFF1D9E75)),
        ),
        const SizedBox(height: 6),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('${(_pct * 100).toStringAsFixed(0)}%',
              style: const TextStyle(fontSize: 11, color: Color(0xFF1D9E75), fontWeight: FontWeight.w500)),
          Text(_fmt(_meta), style: const TextStyle(fontSize: 11, color: Colors.black38)),
        ]),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: () async => await FlutterOverlayWindow.closeOverlay(),
          child: Container(
            width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(border: Border.all(color: Colors.black12, width: 0.5), borderRadius: BorderRadius.circular(8)),
            child: const Center(child: Text('Fechar widget', style: TextStyle(fontSize: 13, color: Colors.black54))),
          ),
        ),
      ]),
    ),
  );
}
