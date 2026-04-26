import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'css_colors.dart';

class ColorPickerField extends StatelessWidget {
  const ColorPickerField({
    super.key,
    required this.value,
    required this.onChanged,
    this.compact = false,
  });

  final Color value;
  final ValueChanged<Color> onChanged;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showDialog(context),
      child: Container(
        height: 32,
        decoration: BoxDecoration(
          color: AppColors.tabInactive,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppColors.border),
        ),
        padding: const EdgeInsets.all(4),
        child: Row(
          mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: value,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: AppColors.border),
              ),
            ),
            if (!compact) ...[
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  colorToHex(value),
                  overflow: TextOverflow.fade,
                  softWrap: false,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontFamily: 'monospace',
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) =>
          _ColorPickerDialog(initialColor: value, onChanged: onChanged),
    );
  }
}

class _ColorPickerDialog extends StatefulWidget {
  const _ColorPickerDialog({
    required this.initialColor,
    required this.onChanged,
  });

  final Color initialColor;
  final ValueChanged<Color> onChanged;

  @override
  State<_ColorPickerDialog> createState() => _ColorPickerDialogState();
}

class _ColorPickerDialogState extends State<_ColorPickerDialog> {
  late HSVColor hsvColor;
  late TextEditingController hexController;
  late TextEditingController htmlController;

  @override
  void initState() {
    super.initState();
    hsvColor = HSVColor.fromColor(widget.initialColor);
    hexController = TextEditingController(
      text: colorToHex(widget.initialColor),
    );
    htmlController = TextEditingController(
      text: cssColorName(widget.initialColor) ?? '',
    );
  }

  @override
  void dispose() {
    hexController.dispose();
    htmlController.dispose();
    super.dispose();
  }

  void _updateFromHsv(HSVColor hsv) {
    setState(() {
      hsvColor = hsv;
      final color = hsv.toColor();
      hexController.text = colorToHex(color);
      htmlController.text = cssColorName(color) ?? '';
    });
    widget.onChanged(hsv.toColor());
  }

  void _updateFromHex(String text) {
    final color = hexToColor(text);
    if (color == null) return;
    setState(() {
      hsvColor = HSVColor.fromColor(color);
      htmlController.text = cssColorName(color) ?? '';
    });
    widget.onChanged(color);
  }

  void _updateFromHtml(String text) {
    final color = parseCssColorName(text);
    if (color == null) return;
    setState(() {
      hsvColor = HSVColor.fromColor(color);
      hexController.text = colorToHex(color);
    });
    widget.onChanged(color);
  }

  @override
  Widget build(BuildContext context) {
    final color = hsvColor.toColor();
    return Dialog(
      backgroundColor: AppColors.panel,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 200,
              height: 200,
              child: _HsvColorDisc(
                hsvColor: hsvColor,
                onChanged: _updateFromHsv,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: 200,
              height: 16,
              child: _ValueSlider(
                hsvColor: hsvColor,
                onChanged: (v) => _updateFromHsv(hsvColor.withValue(v)),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: 200,
              child: Column(
                children: [
                  _buildInputRow('Hex', hexController, _updateFromHex),
                  const SizedBox(height: 8),
                  _buildInputRow('HTML', htmlController, _updateFromHtml),
                  const SizedBox(height: 8),
                  Container(
                    height: 20,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: AppColors.border),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputRow(
    String label,
    TextEditingController controller,
    ValueChanged<String> onChanged,
  ) {
    return Row(
      children: [
        SizedBox(
          width: 40,
          child: Text(
            label,
            style: TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
        ),
        Expanded(
          child: TextField(
            controller: controller,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontFamily: 'monospace',
              fontSize: 13,
            ),
            decoration: InputDecoration(
              filled: true,
              fillColor: AppColors.background,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 6,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(4)),
                borderSide: BorderSide(color: AppColors.accent),
              ),
            ),
            onChanged: onChanged,
            onSubmitted: onChanged,
          ),
        ),
      ],
    );
  }
}

class _HsvColorDisc extends StatelessWidget {
  const _HsvColorDisc({required this.hsvColor, required this.onChanged});

  final HSVColor hsvColor;
  final ValueChanged<HSVColor> onChanged;

  static const double _radius = 100;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanStart: (details) => _updateFromPosition(details.localPosition),
      onPanUpdate: (details) => _updateFromPosition(details.localPosition),
      onTapDown: (details) => _updateFromPosition(details.localPosition),
      behavior: HitTestBehavior.opaque,
      child: CustomPaint(
        size: const Size(_radius * 2, _radius * 2),
        painter: _HsvDiscPainter(hsvColor),
      ),
    );
  }

  void _updateFromPosition(Offset position) {
    final center = const Offset(_radius, _radius);
    final dx = position.dx - center.dx;
    final dy = position.dy - center.dy;
    final distance = math.sqrt(dx * dx + dy * dy);

    var angle = math.atan2(dy, dx) * 180 / math.pi;
    if (angle < 0) angle += 360;

    final saturation = (distance / _radius).clamp(0.0, 1.0);
    onChanged(hsvColor.withHue(angle).withSaturation(saturation));
  }
}

class _HsvDiscPainter extends CustomPainter {
  _HsvDiscPainter(this.hsvColor);

  final HSVColor hsvColor;

  static const double _thumbRadius = 7;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final huePaint = Paint()
      ..shader = SweepGradient(
        center: Alignment.center,
        colors: [
          for (int h = 0; h <= 360; h += 30)
            HSVColor.fromAHSV(1, h.toDouble(), 1, 1).toColor(),
        ],
      ).createShader(rect);
    canvas.drawCircle(center, radius, huePaint);

    final saturationPaint = Paint()
      ..shader = RadialGradient(
        colors: [Colors.white, Colors.white.withValues(alpha: 0)],
      ).createShader(rect);
    canvas.drawCircle(center, radius, saturationPaint);

    if (hsvColor.value < 1.0) {
      final valuePaint = Paint()
        ..color = Colors.black.withValues(alpha: 1.0 - hsvColor.value);
      canvas.drawCircle(center, radius, valuePaint);
    }

    final borderPaint = Paint()
      ..color = AppColors.border
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawCircle(center, radius - 0.5, borderPaint);

    final hueRadians = hsvColor.hue * math.pi / 180;
    final satDistance = hsvColor.saturation * radius;
    final thumbCenter = Offset(
      center.dx + satDistance * math.cos(hueRadians),
      center.dy + satDistance * math.sin(hueRadians),
    );

    final thumbFill = Paint()
      ..color = hsvColor.toColor()
      ..style = PaintingStyle.fill;
    canvas.drawCircle(thumbCenter, _thumbRadius, thumbFill);

    final thumbBorder = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(thumbCenter, _thumbRadius, thumbBorder);
  }

  @override
  bool shouldRepaint(covariant _HsvDiscPainter oldDelegate) {
    return oldDelegate.hsvColor != hsvColor;
  }
}

class _ValueSlider extends StatelessWidget {
  const _ValueSlider({required this.hsvColor, required this.onChanged});

  final HSVColor hsvColor;
  final ValueChanged<double> onChanged;

  static const double _width = 200;
  static const double _height = 16;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanStart: (details) => _updateFromPosition(details.localPosition.dx),
      onPanUpdate: (details) => _updateFromPosition(details.localPosition.dx),
      onTapDown: (details) => _updateFromPosition(details.localPosition.dx),
      behavior: HitTestBehavior.opaque,
      child: CustomPaint(
        size: const Size(_width, _height),
        painter: _ValueSliderPainter(hsvColor),
      ),
    );
  }

  void _updateFromPosition(double dx) {
    final value = (dx / _width).clamp(0.0, 1.0);
    onChanged(value);
  }
}

class _ValueSliderPainter extends CustomPainter {
  _ValueSliderPainter(this.hsvColor);

  final HSVColor hsvColor;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(4));

    final fullColor = HSVColor.fromAHSV(
      1,
      hsvColor.hue,
      hsvColor.saturation,
      1,
    ).toColor();
    final gradientPaint = Paint()
      ..shader = LinearGradient(
        colors: [Colors.black, fullColor],
      ).createShader(rect);
    canvas.drawRRect(rrect, gradientPaint);

    final borderPaint = Paint()
      ..color = AppColors.border
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawRRect(rrect, borderPaint);

    final thumbX = (hsvColor.value * size.width).clamp(6.0, size.width - 6.0);
    final thumbCenter = Offset(thumbX, size.height / 2);

    final thumbFill = Paint()
      ..color = hsvColor.toColor()
      ..style = PaintingStyle.fill;
    canvas.drawCircle(thumbCenter, 6, thumbFill);

    final thumbBorder = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(thumbCenter, 6, thumbBorder);
  }

  @override
  bool shouldRepaint(covariant _ValueSliderPainter oldDelegate) {
    return oldDelegate.hsvColor != hsvColor;
  }
}
