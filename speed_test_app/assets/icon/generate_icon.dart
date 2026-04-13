import 'dart:ui' as ui;
import 'dart:typed_data';
import 'dart:io';

Future<void> main() async {
  // 创建 1024x1024 的图片
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);

  // 绘制背景渐变
  final bgRect = Rect.fromLTWH(0, 0, 1024, 1024);
  final bgPaint = Paint()
    ..shader = ui.Gradient.linear(
      Offset.zero,
      Offset(1024, 1024),
      [Color(0xFF0D47A1), Color(0xFF1565C0), Color(0xFF42A5F5)],
    );

  // 绘制圆角矩形背景
  final rrect = RRect.fromRectAndRadius(bgRect, Radius.circular(180));
  canvas.drawRRect(rrect, bgPaint);

  // 绘制高光层
  final glossRect = Rect.fromLTWH(0, 0, 1024, 512);
  final glossRRect = RRect.fromRectAndRadius(glossRect, Radius.circular(180));
  final glossPaint = Paint()
    ..shader = ui.Gradient.linear(
      Offset(0, 0),
      Offset(0, 512),
      [Color(0xFFFFFFFF).withOpacity(0.3), Color(0xFFFFFFFF).withOpacity(0)],
    );
  canvas.drawRRect(glossRRect, glossPaint);

  // 绘制信号波纹
  final wavePaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 32
    ..strokeCap = StrokeCap.round;

  // 最外层波纹
  wavePaint.color = Color(0xFF64B5F6);
  final path1 = Path();
  path1.moveTo(280, 720);
  path1.quadraticBezierTo(512, 520, 744, 720);
  canvas.drawPath(path1, wavePaint);

  // 中层波纹
  wavePaint.color = Color(0xFF90CAF9);
  final path2 = Path();
  path2.moveTo(340, 680);
  path2.quadraticBezierTo(512, 530, 684, 680);
  canvas.drawPath(path2, wavePaint);

  // 内层波纹
  wavePaint.color = Color(0xFFBBDEFB);
  final path3 = Path();
  path3.moveTo(400, 640);
  path3.quadraticBezierTo(512, 540, 624, 640);
  canvas.drawPath(path3, wavePaint);

  // 中心圆形背景
  final centerCirclePaint = Paint()
    ..color = Color(0xFF1E88E5).withOpacity(0.5);
  canvas.drawCircle(Offset(512, 480), 180, centerCirclePaint);

  // 绘制向上箭头
  final arrowPath = Path();
  arrowPath.moveTo(512, 280);
  arrowPath.lineTo(640, 440);
  arrowPath.lineTo(570, 440);
  arrowPath.lineTo(570, 580);
  arrowPath.lineTo(454, 580);
  arrowPath.lineTo(454, 440);
  arrowPath.lineTo(384, 440);
  arrowPath.close();

  final arrowPaint = Paint()
    ..shader = ui.Gradient.linear(
      Offset(512, 580),
      Offset(512, 280),
      [Color(0xFF90CAF9), Color(0xFFFFFFFF)],
    );
  canvas.drawPath(arrowPath, arrowPaint);

  // 生成图片
  final picture = recorder.endRecording();
  final image = await picture.toImage(1024, 1024);
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

  if (byteData != null) {
    final bytes = byteData.buffer.asUint8List();
    final file = File('assets/icon/app_icon.png');
    await file.writeAsBytes(bytes);
    print('Icon generated: ${file.path}');
  }
}
