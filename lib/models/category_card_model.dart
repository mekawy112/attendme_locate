import 'package:flutter/widgets.dart';

class CategoryCardModel {
  final String imageUrl;
  final String categoryName;
  final Icon icon;
  const CategoryCardModel(
      {required this.imageUrl, required this.categoryName, required this.icon});
}
