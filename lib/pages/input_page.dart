import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../model/match_record.dart';

class InputPage extends StatefulWidget {
  const InputPage({super.key});

  @override
  State<InputPage> createState() => _InputPageState();
}

class MatchInput {
  late TextEditingController opponentCtrl;
  String opponentLrig = "";
  String firstSecond = "先手";
  String result = "勝";
  int selfLb = 0;
  int opponentLb = 0;
  String memo = "";

  // メモ用コントローラ
  late TextEditingController memoCtrl;

  MatchInput() {
    opponentCtrl = TextEditingController();
    memoCtrl = TextEditingController(text: memo);
  }

  void dispose() {
    opponentCtrl.dispose();
    memoCtrl.dispose();
  }
}

class _InputPageState extends State<InputPage> {
  final eventCtrl = TextEditingController();
  final usedCtrl = TextEditingController();

final List<String> lrigList = [
  "リメンバ",
  "ピルルク",
  "タマ",
  "ウリス",
  "ドーナ",
  "アン",
  "エルドラ",
];
  
  DateTime date = DateTime.now();
  String format = "A";

  List<MatchInput> matches = [MatchInput()];

  String? imagePath;

  /// ラベル
  Widget label(String t) => Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(t, style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
      );

  /// 画像選択
  Future<void> pickImage() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery);

    if (file == null) return;

    final dir = await getApplicationDocumentsDirectory();
    final name = DateTime.now().millisecondsSinceEpoch.toString();

    final saved = await File(file.path).copy('${dir.path}/$name.jpg');

    setState(() {
      imagePath = saved.path;
    });
  }

  /// 保存
  void save() {
    final box = Hive.box<MatchRecord>('records');

    for (int i = 0; i < matches.length; i++) {
      final m = matches[i];

      box.add(
        MatchRecord(
          eventName: eventCtrl.text,
          date: date,
          format: format,
          usedLrig: usedCtrl.text,
          round: i + 1,
          opponentLrig: m.opponentCtrl.text,
          firstSecond: m.firstSecond,
          result: m.result,
          selfLb: m.selfLb,
          opponentLb: m.opponentLb,
          memo: m.memoCtrl.text,
          imagePath: imagePath,
        ),
      );
    }

    /// 🔥 完全リセット
setState(() {
  eventCtrl.clear();
  usedCtrl.clear();
  imagePath = null;
  date = DateTime.now();
  format = "A";

  // 古いコントローラを破棄して、新しい対戦1件に置き換え
  for (var m in matches) {
    m.dispose();
  }
  matches = [MatchInput()]; // 対戦数は1件にリセット
});

  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text("保存しました")),
    );
  }

  @override
  void dispose() {
    eventCtrl.dispose();
    usedCtrl.dispose();
    for (var m in matches) {
      m.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          /// 画像
          label("デッキレシピ"),
          ElevatedButton(
            onPressed: pickImage,
            child: const Text("画像を選択"),
          ),
          if (imagePath != null && File(imagePath!).existsSync())
              Image.file(File(imagePath!), height: 120),

          label("大会名"),
          TextField(controller: eventCtrl),

          label("日付"),
          GestureDetector(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: date,
                firstDate: DateTime(2020),
                lastDate: DateTime(2100),
              );
              if (picked != null) {
                setState(() => date = picked);
              }
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(border: Border.all()),
              child: Text("${date.year}/${date.month}/${date.day}"),
            ),
          ),

          label("使用ルリグ"),
          TextField(controller: usedCtrl),

          label("フォーマット"),
          DropdownButton(
            value: format,
            isExpanded: true,
            items: ['A', 'K', 'D']
                .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                .toList(),
            onChanged: (v) => setState(() => format = v!),
          ),

          const SizedBox(height: 10),

          /// 対戦入力
          ...List.generate(matches.length, (i) {
            final m = matches[i];

            return Card(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  children: [
                    label("対戦 ${i + 1}"),

                    label("対面ルリグ"),
                    TextField(
                      controller: m.opponentCtrl, // ← ここでコントローラを使用
                    ),

                    label("先後"),
                    DropdownButton(
                      value: m.firstSecond,
                      isExpanded: true,
                      items: ["先手", "後手"]
                          .map((e) =>
                              DropdownMenuItem(value: e, child: Text(e)))
                          .toList(),
                      onChanged: (v) => setState(() => m.firstSecond = v!),
                    ),

                    label("勝敗"),
                    DropdownButton(
                      value: m.result,
                      isExpanded: true,
                      items: ["勝", "負"]
                          .map((e) =>
                              DropdownMenuItem(value: e, child: Text(e)))
                          .toList(),
                      onChanged: (v) => setState(() => m.result = v!),
                    ),

                    label("LB数:自/被"),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButton(
                            value: m.selfLb,
                            isExpanded: true,
                            items: List.generate(
                                10,
                                (i) =>
                                    DropdownMenuItem(value: i, child: Text("$i"))),
                            onChanged: (v) => setState(() => m.selfLb = v!),
                          ),
                        ),
                        const Text("-"),
                        Expanded(
                          child: DropdownButton(
                            value: m.opponentLb,
                            isExpanded: true,
                            items: List.generate(
                                10,
                                (i) =>
                                    DropdownMenuItem(value: i, child: Text("$i"))),
                            onChanged: (v) => setState(() => m.opponentLb = v!),
                          ),
                        ),
                      ],
                    ),

                    label("メモ"),
                    TextField(
                      controller: m.memoCtrl,
                      maxLines: null,
                    ),

                    const SizedBox(height: 10),
                    if (matches.length > 1)
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            m.dispose();
                            matches.removeAt(i);
                          });
                        },
                        child: const Text("削除"),
                      ),
                  ],
                ),
              ),
            );
          }),

          ElevatedButton(
            onPressed: () {
              setState(() => matches.add(MatchInput()));
            },
            child: const Text("+ 対戦追加"),
          ),

          ElevatedButton(
            onPressed: save,
            child: const Text("保存"),
          ),
        ],
      ),
    );
  }
}
