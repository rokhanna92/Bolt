import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../app/share.dart';
import '../../core/format.dart';
import '../../data/bolt_store.dart';
import '../../services/haptics.dart';
import '../../theme/text_styles.dart';
import '../../theme/tokens.dart';
import '../../widgets/bolt_sheet.dart';
import '../../widgets/box.dart';
import '../../widgets/common.dart';
import '../../widgets/tap.dart';

/// Where a friend gets Bolt. The page shows them how to install it.
const kInviteUrl = 'https://bolt.x3kk3x.cloud';

/// Opens a QR code a friend can scan to get Bolt.
class CallFriendCard extends StatelessWidget {
  const CallFriendCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Tap(
      onTap: () {
        Haptics.play(Feel.tap);
        showBoltSheet<void>(context, (_) => const _CallFriendSheet());
      },
      child: BoltBox(
        color: BoltColors.surface1,
        radius: 18,
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            BoltBox(
              width: 42,
              height: 42,
              radius: 12,
              stroke: Stroke(BoltColors.neon, 1.5),
              alignment: Alignment.center,
              child: BoltIcon('group', size: 20, color: BoltColors.neon),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tx('Call a friend'), style: BoltText.a(15, weight: 800)),
                  const SizedBox(height: 2),
                  Text(tx('Show them a code that gets them into Bolt'), style: BoltText.a(12, color: BoltColors.muted)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Chevron(),
          ],
        ),
      ),
    );
  }
}

class _CallFriendSheet extends ConsumerWidget {
  const _CallFriendSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(tx('Call a friend'), style: BoltText.a(20, weight: 900)),
        const SizedBox(height: 6),
        Text(
          tx('They point their camera at this code, and Bolt shows them how to install it on their phone.'),
          style: BoltText.a(13, color: BoltColors.muted, height: 1.45),
        ),
        const SizedBox(height: 16),
        Center(
          child: BoltBox(
            color: const Color(0xFFFFFFFF),
            radius: 18,
            padding: const EdgeInsets.all(16),
            child: QrImageView(
              data: kInviteUrl,
              size: 208,
              padding: EdgeInsets.zero,
              gapless: true,
              errorCorrectionLevel: QrErrorCorrectLevel.M,
              eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: BoltColors.ink),
              dataModuleStyle: const QrDataModuleStyle(
                dataModuleShape: QrDataModuleShape.square,
                color: BoltColors.ink,
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          kInviteUrl.replaceFirst('https://', ''),
          textAlign: TextAlign.center,
          style: BoltText.m(12, color: BoltColors.muted),
        ),
        const SizedBox(height: 14),
        Text(
          tx('They will also need a key from the owner of Bolt.'),
          textAlign: TextAlign.center,
          style: BoltText.a(12, color: BoltColors.muted),
        ),
        const SizedBox(height: 14),
        OutlineButton(
          label: tx('Share the link'),
          onTap: () async {
            final store = ref.read(boltProvider.notifier);
            final hint = await shareMessage(tx('Try Bolt, the gym app: {url}', {'url': kInviteUrl}), subject: 'Bolt');
            if (hint != null) store.toast(hint);
          },
        ),
      ],
    );
  }
}
