import 'package:flutter/material.dart';

import '../../../../core/theming/styles.dart';
import 'my_rich_text.dart';


class WelcomeText extends StatelessWidget {
  const WelcomeText({super.key});

  @override
  Widget build(BuildContext context) {
    return MyRichText(
        firstText: 'Welcome,\n',
        firstTextStyle: TextStyles.font24DarkBlueMedium,
        secondTextStyle:TextStyles.font24DarkBlueMedium,
        secondText:'Nourhan Magdy'
      // '${CacheHelper.getData(key: 'displayName').split(' ')[0]} ${CacheHelper.getData(key: 'displayName').split(' ')[1]}',

    );
  }
}
