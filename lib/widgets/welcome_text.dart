import 'package:flutter/material.dart';

import '../../../../core/theming/styles.dart';
import 'my_rich_text.dart';


class WelcomeText extends StatelessWidget {
  final Map<String, dynamic>? userData;
  
  const WelcomeText({super.key, this.userData});

  @override
  Widget build(BuildContext context) {
    // إذا كان userData متوفر، استخدمه لعرض اسم المستخدم، وإلا اعرض اسمًا افتراضيًا
    String userName = "Guest";
    if (userData != null && userData!['name'] != null) {
      userName = userData!['name'];
    }
    
    return MyRichText(
        firstText: 'Welcome,\n',
        firstTextStyle: TextStyles.font24DarkBlueMedium,
        secondTextStyle: TextStyles.font24DarkBlueMedium,
        secondText: userName
    );
  }
}
