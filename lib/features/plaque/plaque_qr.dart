import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../data/seed/demo.dart';
import '../../theme/tokens.dart';

/// The gym's permanent check-in code, `bolt://checkin?gym=<plaque_token>`.
class PlaqueQr extends StatelessWidget {
  const PlaqueQr({super.key, this.color = BoltColors.ink});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return QrImageView(
      data: Gym.plaqueUri,
      padding: EdgeInsets.zero,
      gapless: true,
      errorCorrectionLevel: QrErrorCorrectLevel.M,
      eyeStyle: QrEyeStyle(eyeShape: QrEyeShape.square, color: color),
      dataModuleStyle: QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: color),
    );
  }
}
