import 'package:flutter/material.dart';

import '../../../../core/theming/styles.dart';
import 'my_rich_text.dart';


class WelcomeText extends StatelessWidget {
  const WelcomeText({super.key});

  @override
  Widget build(BuildContext context) {
    return MyRichText(
        firstText: 'Welcome,\n',
        firstTextStyle: TextStyles.font24BlueSemiBold,
        secondTextStyle: TextStyles.font24BlueRegular,
        secondText:'Nourhan Magdy'
      // '${CacheHelper.getData(key: 'displayName').split(' ')[0]} ${CacheHelper.getData(key: 'displayName').split(' ')[1]}',

    );
  }
}
