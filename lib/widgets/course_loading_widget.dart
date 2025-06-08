import 'package:attend_me_locate/widgets/section_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../core/helpers/spacing.dart';
import '../core/theming/colors.dart';

class CoursesLoadingWidget extends StatelessWidget {
  const CoursesLoadingWidget({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SectionHeader(sectionTitle: 'Courses', icon: Icons.menu_book_outlined,),
        // verticalSpacing(5),
        SizedBox(
          height: 80.h,
          child: ListView.separated(
            separatorBuilder: (context, index) => horizontalSpacing(30),
            itemCount: 4,
            scrollDirection: Axis.horizontal,
            itemBuilder: (context, index) {
              return Center(
                child: Container(
                  height: 70.h,
                  width: 70.w,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: ColorsManager.blueColor,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey[300]!,
                        blurRadius: 1,
                        spreadRadius: 2,
                        offset: const Offset(2, 2),
                      ),
                      const BoxShadow(
                        color: ColorsManager.whiteColor,
                        blurRadius: 2,
                        spreadRadius: 1,
                        offset: Offset(-2, -2),
                      ),
                    ],
                  ),
                  child: Center(child: Text('CS21')),
                  // child: const Center(
                  //   child: CircularProgressIndicator(
                  //     color: ColorsManager.blueColor,
                  //     strokeWidth: .5,
                  //   ),

                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
