import 'package:fit_book/food/edit_food_page.dart';
import 'package:fit_book/food/food_page.dart';
import 'package:flutter/material.dart' as material;
import 'package:flutter/material.dart';

class FoodList extends StatefulWidget {
  const FoodList({
    super.key,
    required this.foods,
    required this.selected,
    required this.onSelect,
    required this.onNext,
  });

  final List<PartialFood> foods;
  final Set<int> selected;
  final Function(int) onSelect;
  final Function() onNext;

  @override
  State<FoodList> createState() => _FoodListState();
}

class _FoodListState extends State<FoodList> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_scrollListener);
  }

  @override
  void dispose() {
    super.dispose();
    _scrollController.removeListener(_scrollListener);
  }

  void _scrollListener() {
    if (_scrollController.position.pixels <
        _scrollController.position.maxScrollExtent - 200) return;
    widget.onNext();
  }

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: ListView.builder(
        controller: _scrollController,
        itemCount: widget.foods.length,
        itemBuilder: (context, index) {
          final food = widget.foods[index];
          final previous = index > 0 ? widget.foods[index - 1] : null;
          final showDivider = previous != null &&
              (food.favorite ?? false) != (previous.favorite ?? false);

          return material.Column(
            children: [
              if (showDivider)
                const Row(
                  children: [
                    Expanded(child: Divider()),
                    Icon(Icons.favorite_outline),
                    Expanded(child: Divider()),
                  ],
                ),
              ListTile(
                title: Text(food.name),
                subtitle: Text(
                  "${food.calories?.toStringAsFixed(0)} kcal",
                ),
                selected: widget.selected.contains(food.id),
                onLongPress: () => widget.onSelect(food.id),
                onTap: () {
                  if (widget.selected.isEmpty)
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => EditFoodPage(
                          id: food.id,
                        ),
                      ),
                    );
                  else
                    widget.onSelect(food.id);
                },
              ),
            ],
          );
        },
      ),
    );
  }
}
