
import 'package:flutter/material.dart';

import '../core/theming/colors.dart';
import '../core/theming/font_weight_helpers.dart';
import '../core/theming/styles.dart';

class AppTextFormField extends StatelessWidget {
  final EdgeInsetsGeometry? contentPadding;
  final InputBorder? focusedBorder;
  final InputBorder? enabledBorder;
  final TextStyle? inputTextStyle;
  final TextStyle? hintStyle;
  final String hintText;
  final bool? isObscureText;
  final Widget? suffixIcon;
  final Color? backgroundColor;
  final TextEditingController? controller;
  final String? label;
  // final Function(String?) validator;
  final Color? cursorColor;
  final TextInputType? keyboardType;
  final Widget? prefixIcon;
  final bool? enabled;
  final TextStyle? style;
  final TextStyle? labelStyle;

  const AppTextFormField({
    super.key,
    this.contentPadding,
    this.focusedBorder,
    this.enabledBorder,
    this.inputTextStyle,
    this.hintStyle,
    required this.hintText,
    this.isObscureText,
    this.suffixIcon,
    this.backgroundColor,
    this.controller,
    //required this.validator,
     this.label,
    this.cursorColor,
    this.keyboardType,
    this.prefixIcon,
    this.enabled,
    this.style,
    this.labelStyle,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      keyboardType: keyboardType ?? TextInputType.text,
      cursorColor: cursorColor ?? ColorsManager.blueColor,
      controller: controller,
      enabled: enabled ?? true,
      decoration: InputDecoration(
        prefixIcon: prefixIcon,
        prefixIconColor: ColorsManager.blueColor,
        labelText: label,
        labelStyle: labelStyle ?? TextStyles.font18DarkBlueRegular.copyWith(color: ColorsManager.blueColor),
        isDense: true,
        alignLabelWithHint: false,
        contentPadding: contentPadding ??
            EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 10,
            ),
        focusedBorder: focusedBorder ??
            UnderlineInputBorder(
              borderSide: BorderSide(
                color: backgroundColor ?? ColorsManager.blueColor,
                width: 2,
              ),
            ),
        enabledBorder: enabledBorder ??
            UnderlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(
                color: ColorsManager.greyColor,
                width: 2,
              ),
            ),
        errorBorder: UnderlineInputBorder(
          borderSide: const BorderSide(
            color: ColorsManager.darkBlueColor1,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        focusedErrorBorder: UnderlineInputBorder(
          borderSide: const BorderSide(
            color: Colors.red,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        hintStyle: hintStyle ??
            TextStyles.font14BlackMedium
                .copyWith(fontWeight: FontWeightHelper.medium, color: ColorsManager.greyColor),
        hintText: hintText,
        suffixIcon: suffixIcon,
        fillColor: backgroundColor ?? Colors.white.withOpacity(0.05),
        filled: true,
      ),
      obscureText: isObscureText ?? false,
      style: style ?? TextStyles.font14BlackMedium.copyWith(
        fontWeight: FontWeightHelper.medium,
        color: ColorsManager.blueColor
      ),
      // validator: (value) {
      //   return validator(value);
      // },
    );
  }
}
