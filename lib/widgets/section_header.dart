import 'package:flutter/material.dart';
import '../core/helpers/spacing.dart';
import '../core/theming/colors.dart';
import '../core/theming/styles.dart';

class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.sectionTitle,
    required this.icon,
    this.traillingWidget,
  });

  final String sectionTitle;
  final IconData icon;
  final Widget? traillingWidget;
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          sectionTitle,
          style: TextStyles.font20BlueSemiBold,
        ),
        horizontalSpacing(10),
        Icon(
          icon,
          color: ColorsManager.darkBlueColor1,
        ),
        const Spacer(),
        traillingWidget ?? const SizedBox.shrink(),
      ],
    );
  }
}
