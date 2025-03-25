
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
  final String label;
  // final Function(String?) validator;
  final Color? cursorColor;
  final TextInputType? keyboardType;
  final Widget? prefixIcon;
  final bool? enabled;

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
    required this.label,
    this.cursorColor,
    this.keyboardType,
    this.prefixIcon,
    this.enabled,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      keyboardType: keyboardType ?? TextInputType.text,
      cursorColor: cursorColor ?? ColorsManager.darkBlueColor1,
      controller: controller,
      enabled: enabled ?? true,
      decoration: InputDecoration(
        prefixIcon: prefixIcon,
        prefixIconColor: ColorsManager.darkBlueColor1,
        labelText: label,
        labelStyle: TextStyles.font14BlackMedium.copyWith(color: Colors.grey),
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
            TextStyles.font14WhiteRegular
                .copyWith(fontWeight: FontWeightHelper.medium),
        hintText: hintText,
        suffixIcon: suffixIcon,
        fillColor: backgroundColor ?? Colors.transparent,
        filled: true,
      ),
      obscureText: isObscureText ?? false,
      style: inputTextStyle ?? TextStyles.font14WhiteRegular,
      // validator: (value) {
      //   return validator(value);
      // },
    );
  }
}
