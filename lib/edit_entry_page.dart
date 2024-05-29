import 'package:drift/drift.dart';
import 'package:fit_book/constants.dart';
import 'package:fit_book/main.dart';
import 'package:fit_book/settings_state.dart';
import 'package:fit_book/utils.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'database.dart';

class EditEntryPage extends StatefulWidget {
  final int? id;

  const EditEntryPage({super.key, this.id});

  @override
  createState() => _EditEntryPageState();
}

class _EditEntryPageState extends State<EditEntryPage> {
  final _quantityController = TextEditingController(text: "0");
  final _caloriesController = TextEditingController(text: "0");
  final _kilojoulesController = TextEditingController(text: "0");
  final _proteinController = TextEditingController(text: "0");
  final _proteinNode = FocusNode();

  late String _name;
  late SettingsState _settings;

  DateTime _created = DateTime.now();
  var _unit = 'serving';
  bool _foodDirty = false;
  Food? _selectedFood;
  TextEditingController? _nameController;

  @override
  void initState() {
    super.initState();
    _settings = context.read<SettingsState>();
    if (widget.id == null) return;

    (db.entries.select()..where((u) => u.id.equals(widget.id!)))
        .getSingle()
        .then(
      (entry) async {
        setState(() {
          _quantityController.text = entry.quantity.toString();
          _created = entry.created;
          _unit = entry.unit;
        });

        final food = await (db.foods.select()
              ..where((u) => u.id.equals(entry.id)))
            .getSingleOrNull();
        if (food == null) return;

        setState(() {
          _name = food.name;
          _selectedFood = food;
          _caloriesController.text = food.calories?.toString() ?? "";
          _proteinController.text = food.proteinG?.toString() ?? "";
          _kilojoulesController.text = food.calories == null
              ? ''
              : (food.calories! * 4.184).toStringAsFixed(2);
        });
      },
    );
  }

  Future<List<String>> _search(String term) async {
    return await (db.foods.selectOnly()
          ..where(db.foods.name.contains(term.toLowerCase()))
          ..limit(30)
          ..orderBy([
            OrderingTerm(
              expression: db.foods.favorite,
              mode: OrderingMode.desc,
            ),
          ])
          ..addColumns([db.foods.name, db.foods.favorite]))
        .get()
        .then(
          (results) =>
              results.map((result) => result.read(db.foods.name)!).toList(),
        );
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _saveFood() async {
    if (_selectedFood?.name != _nameController?.text) {
      final foodId = await (db.foods.insertOne(
        FoodsCompanion.insert(
          name: _nameController!.text,
          calories: Value(double.tryParse(_caloriesController.text)),
          proteinG: Value(double.tryParse(_proteinController.text)),
          favorite: Value(_settings.favoriteNew),
        ),
      ));
      final food = await (db.foods.select()..where((u) => u.id.equals(foodId)))
          .getSingle();
      setState(() {
        _selectedFood = food;
      });
    } else {
      await (db.foods.update()
            ..where((u) => u.id.equals(_selectedFood?.id ?? -1)))
          .write(
        FoodsCompanion(
          proteinG: Value(double.tryParse(_proteinController.text)),
          calories: Value(double.tryParse(_caloriesController.text)),
        ),
      );
      final food = await (db.foods.select()
            ..where((u) => u.id.equals(_selectedFood!.id)))
          .getSingle();
      setState(() {
        _selectedFood = food;
      });
    }
  }

  Future<void> _save() async {
    if (_foodDirty) await _saveFood();

    final food = _selectedFood!;

    final quantity = double.parse(_quantityController.text);
    var entry = EntriesCompanion.insert(
      food: food.id,
      created: _created,
      quantity: quantity,
      unit: _unit,
    );

    if (_unit == 'kilojoules') {
      final grams = quantity / 4.184;
      entry = entry.copyWith(
        kCalories: Value(grams / 100 * (food.calories ?? 1)),
      );
    } else {
      double quantity100G;
      if (_unit == 'serving') {
        quantity100G = quantity; // 1 serving
      } else {
        quantity100G = convertToGrams(quantity, _unit) / 100;
      }
      final kCalories = quantity100G * (food.calories ?? 100);
      final proteinG = quantity100G * (food.proteinG ?? 0);
      final fatG = quantity100G * (food.fatG ?? 0);
      final carbG = quantity100G * (food.carbohydrateG ?? 0);
      entry = entry.copyWith(
        kCalories: Value(kCalories),
        fatG: Value(fatG),
        carbG: Value(carbG),
        proteinG: Value(proteinG),
      );
    }

    if (widget.id == null)
      await db.into(db.entries).insert(entry);
    else
      await db.update(db.entries).replace(
            entry.copyWith(
              id: Value(entry.id.value),
            ),
          );
    if (!mounted) return;
    Navigator.pop(context);
  }

  Future<void> _selectDate() async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _created,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (pickedDate != null) {
      _selectTime(pickedDate);
    }
  }

  Future<void> _selectTime(DateTime pickedDate) async {
    if (!_settings.longDateFormat.contains('h:mm'))
      return setState(() {
        _created = pickedDate;
      });

    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_created),
    );

    if (pickedTime != null) {
      setState(() {
        _created = DateTime(
          pickedDate.year,
          pickedDate.month,
          pickedDate.day,
          pickedTime.hour,
          pickedTime.minute,
        );
      });
    }
  }

  void _recalc() {
    final food = _selectedFood!;
    final quantity = double.parse(_quantityController.text);
    if (_unit == 'kilojoules') {
      final grams = quantity / 4.184;
      final kCalories = grams / 100 * (food.calories ?? 1);
      setState(() {
        _caloriesController.text = kCalories.toString();
      });
    } else {
      double quantity100G;
      if (_unit == 'serving') {
        quantity100G = quantity; // 1 serving
      } else {
        quantity100G = convertToGrams(quantity, _unit) / 100;
      }
      final kCalories = quantity100G * (food.calories ?? 100);
      final proteinG = quantity100G * (food.proteinG ?? 0);
      setState(() {
        _caloriesController.text = kCalories.toString();
        _proteinController.text = proteinG.toString();
        _kilojoulesController.text = (kCalories * 4.184).toStringAsFixed(2);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    _settings = context.watch<SettingsState>();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.id == null ? 'Add entry' : 'Edit entry',
        ),
        actions: [
          if (widget.id != null)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () async {
                await showDialog(
                  context: context,
                  builder: (BuildContext dialogContext) {
                    return AlertDialog(
                      title: const Text('Confirm Delete'),
                      content: Text(
                        'Are you sure you want to delete ${_selectedFood?.name}?',
                      ),
                      actions: <Widget>[
                        TextButton(
                          child: const Text('Cancel'),
                          onPressed: () {
                            Navigator.pop(dialogContext);
                          },
                        ),
                        TextButton(
                          child: const Text('Delete'),
                          onPressed: () async {
                            Navigator.pop(dialogContext);
                            await db.entries.deleteWhere(
                              (tbl) => tbl.id.equals(widget.id!),
                            );
                            if (context.mounted) Navigator.pop(context);
                          },
                        ),
                      ],
                    );
                  },
                );
              },
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            Autocomplete<String>(
              optionsMaxHeight: 300,
              optionsBuilder: (textEditingValue) {
                if (textEditingValue.text.isEmpty) return [];
                return _search(textEditingValue.text);
              },
              onSelected: (option) async {
                final food = await (db.foods.select()
                      ..where((tbl) => tbl.name.equals(option))
                      ..limit(1))
                    .getSingleOrNull();
                if (food == null) return;
                setState(() {
                  _foodDirty = false;
                  _selectedFood = food;
                });
                _recalc();
              },
              initialValue: TextEditingValue(text: _name),
              fieldViewBuilder: (
                BuildContext context,
                TextEditingController textEditingController,
                FocusNode focusNode,
                VoidCallback onFieldSubmitted,
              ) {
                _nameController = textEditingController;
                return TextFormField(
                  decoration: const InputDecoration(labelText: 'Name'),
                  autofocus: widget.id == null,
                  controller: textEditingController,
                  focusNode: focusNode,
                  textCapitalization: TextCapitalization.sentences,
                  onFieldSubmitted: (String value) {
                    onFieldSubmitted();
                  },
                  onChanged: (value) => setState(() {
                    _name = value;
                  }),
                );
              },
            ),
            TextField(
              controller: _quantityController,
              decoration: const InputDecoration(label: Text("Quantity")),
              keyboardType: TextInputType.number,
              onTap: () => _quantityController.selection = TextSelection(
                baseOffset: 0,
                extentOffset: _quantityController.text.length,
              ),
              onChanged: (value) {
                _recalc();
              },
            ),
            DropdownButtonFormField<String>(
              value: _unit,
              decoration: const InputDecoration(labelText: 'Unit'),
              items: units.map((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
              onChanged: (String? newValue) {
                setState(() {
                  _unit = newValue!;
                });
                _recalc();
              },
            ),
            TextField(
              controller: _caloriesController,
              decoration: InputDecoration(
                labelText: 'Calories ${_foodDirty ? '(per 100g)' : ''}',
              ),
              onTap: () => selectAll(_caloriesController),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              onChanged: (value) {
                setState(() {
                  _foodDirty = true;
                  _kilojoulesController.text =
                      ((double.tryParse(value) ?? 0) * 4.184)
                          .toStringAsFixed(2);
                });
              },
              onSubmitted: (value) {
                _proteinNode.requestFocus();
                selectAll(_proteinController);
              },
            ),
            if (_unit != 'kilojoules')
              TextField(
                controller: _kilojoulesController,
                decoration: InputDecoration(
                  labelText: 'Kilojoules ${_foodDirty ? '(per 100g)' : ''}',
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                onChanged: (value) {
                  setState(() {
                    _foodDirty = true;
                    _caloriesController.text =
                        ((double.tryParse(value) ?? 0) / 4.184)
                            .toStringAsFixed(2);
                  });
                },
                onTap: () => selectAll(_kilojoulesController),
              ),
            TextField(
              controller: _proteinController,
              focusNode: _proteinNode,
              decoration: InputDecoration(
                labelText: 'Protein ${_foodDirty ? '(per 100g)' : ''}',
              ),
              onTap: () => selectAll(_proteinController),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              onChanged: (value) {
                setState(() {
                  _foodDirty = true;
                });
              },
            ),
            ListTile(
              title: const Text('Created Date'),
              subtitle:
                  Text(DateFormat(_settings.longDateFormat).format(_created)),
              trailing: const Icon(Icons.calendar_today),
              onTap: () => _selectDate(),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _save,
        child: const Icon(Icons.save),
      ),
    );
  }
}
