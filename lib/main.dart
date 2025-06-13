import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geocoding/geocoding.dart';
import 'dart:math';

void main() {
  runApp(
    MaterialApp(
      home: cheng114finalHome(),
      debugShowCheckedModeBanner: false,
    ),
  );
}

class cheng114finalHome extends StatefulWidget {
  @override
  _cheng114finalHomeState createState() => _cheng114finalHomeState();
}

class _cheng114finalHomeState extends State<cheng114finalHome> {
  List<TextEditingController> _controllers = [TextEditingController()];
  List<String> _coordinates = [];
  List<LatLng> _latLngList = [];
  List<String> _addressList = [];
  List<String> _distanceSteps = [];
  String _asciiTree = '';
  String _totalDistance = '';
  String _explanation = '';

  void _addAddressField() {
    setState(() {
      _controllers.add(TextEditingController());
      _coordinates.add('');
    });
  }

  void _removeAddressField(int index) {
    setState(() {
      if (_controllers.length > 1) {
        _controllers.removeAt(index);
        _coordinates.removeAt(index);
      }
    });
  }

  Future<void> _fetchCoordinates() async {
    List<String> results = [];
    List<LatLng> coords = [];
    List<String> addresses = [];

    for (var controller in _controllers) {
      String address = controller.text.trim();
      if (address.isEmpty) {
        results.add('❌ 請輸入地址');
        continue;
      }

      try {
        List<Location> locations = await locationFromAddress(address);
        if (locations.isNotEmpty) {
          Location loc = locations.first;
          results.add('${loc.latitude},${loc.longitude}');
          coords.add(LatLng(loc.latitude, loc.longitude));
          addresses.add(address);
        } else {
          results.add('⚠️ 找不到位置');
        }
      } catch (e) {
        results.add('❗錯誤：$e');
      }
    }

    setState(() {
      _coordinates = results;
      _latLngList = coords;
      _addressList = addresses;
    });
  }

  void _solveTSPWithSteps() async {
    await _fetchCoordinates();
    if (_latLngList.length < 3) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('請輸入至少三個有效地址才能計算最短路徑')));
      return;
    }

    final n = _latLngList.length;
    final visited = List<bool>.filled(n, false);
    final path = <int>[];
    double best = double.infinity;
    List<int> bestPath = [];
    String asciiLog = '';

    void dfs(int current, double dist, int depth, String prefix) {
      if (depth == n) {
        double back = _haversine(_latLngList[current], _latLngList[0]);
        double total = dist + back;
        asciiLog +=
            '$prefix└ 回到起點 ${_addressList[0]} (+${back.toStringAsFixed(2)}) 總計=${total.toStringAsFixed(2)}\n';
        if (total < best) {
          best = total;
          bestPath = List<int>.from(path);
        }
        return;
      }

      for (int i = 0; i < n; i++) {
        if (!visited[i]) {
          visited[i] = true;
          path.add(i);
          double d =
              path.length > 1
                  ? _haversine(
                    _latLngList[path[path.length - 2]],
                    _latLngList[i],
                  )
                  : 0;
          asciiLog +=
              '$prefix├ 探索 ${_addressList[i]} (+${d.toStringAsFixed(2)})\n';
          dfs(i, dist + d, depth + 1, prefix + '│  ');
          visited[i] = false;
          path.removeLast();
        }
      }
    }

    visited[0] = true;
    path.add(0);
    asciiLog += '[Start] ${_addressList[0]}\n';
    dfs(0, 0, 1, '');

    // 轉換最佳路徑為文字步驟
    List<String> steps = [];
    for (int i = 0; i < bestPath.length - 1; i++) {
      double d = _haversine(
        _latLngList[bestPath[i]],
        _latLngList[bestPath[i + 1]],
      );
      steps.add(
        '${_addressList[bestPath[i]]} ➡️ ${_addressList[bestPath[i + 1]]} = ${d.toStringAsFixed(2)}',
      );
    }
    double d = _haversine(_latLngList[bestPath.last], _latLngList[0]);
    steps.add(
      '${_addressList[bestPath.last]} ➡️ ${_addressList[0]} = ${d.toStringAsFixed(2)}',
    );

    _explanation = '''使用 DFS（深度優先搜尋）+ 回溯法。
每次從起點出發，試走所有排列可能，記錄距離，找出最短。

1. 起點固定：第一筆地址當作起點。
2. 每次往下一個未訪問的點走，累積距離。
3. 一路走到底再回到起點，並記錄總距離。
4. 如果比目前最佳解還短，則更新最佳解。

整個過程會記錄成 ASCII 樹狀圖來幫助觀察遞迴過程與每一步的選擇。''';

    setState(() {
      _asciiTree = asciiLog;
      _totalDistance = best.toStringAsFixed(2);
      _distanceSteps = steps;
    });
  }

  void _showAsciiTreeDialog() {
    showDialog(
      context: context,
      builder:
          (_) => AlertDialog(
            title: Text('TSP 計算過程'),
            content: SingleChildScrollView(
              child: Text(
                _explanation +
                    '\n=========================\n\n' +
                    _asciiTree +
                    '\n=========================\n最短總距離: $_totalDistance km',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('關閉'),
              ),
            ],
          ),
    );
  }

  double _haversine(LatLng p1, LatLng p2) {
    const R = 6371;
    final dLat = _toRadians(p2.lat - p1.lat);
    final dLon = _toRadians(p2.lon - p1.lon);
    final a =
        pow(sin(dLat / 2), 2) +
        cos(_toRadians(p1.lat)) *
            cos(_toRadians(p2.lat)) *
            pow(sin(dLon / 2), 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  double _toRadians(double deg) => deg * pi / 180;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('售貨員旅行解決器')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ListView.builder(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              itemCount: _controllers.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(0, 8, 0, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _controllers[index],
                          decoration: InputDecoration(
                            labelText: '地址 ${index + 1}',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.remove),
                        onPressed: () => _removeAddressField(index),
                      ),
                    ],
                  ),
                );
              },
            ),
            Row(
              children: [
                ElevatedButton.icon(
                  icon: Icon(Icons.add),
                  label: Text('新增地址'),
                  onPressed: _addAddressField,
                ),
                SizedBox(width: 6),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _solveTSPWithSteps,
                    child: Text('計算路徑'),
                  ),
                ),
                SizedBox(width: 6),
                ElevatedButton(
                  onPressed: _showAsciiTreeDialog,
                  child: Text('計算方式'),
                ),
              ],
            ),
            SizedBox(height: 16),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '最短路徑 (點一下拷貝)',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),

            ..._distanceSteps.map(
              (step) =>
                  GestureDetector(onTap:(){
                      Clipboard.setData(ClipboardData(text: _distanceSteps.join('\n')));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('已拷貝最短路徑')),
                      );
                  } ,child: Align(alignment: Alignment.centerLeft, child: Text(step))),
            ),
            SizedBox(height: 20),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '經緯度列表 (共${_coordinates.length} 筆，點一下拷貝單筆)',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            ..._coordinates.asMap().entries.map((entry) {
              int index = entry.key;
              String coord = entry.value;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: coord));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('已複製第 ${index + 1} 筆經緯度')),
                          );
                        },
                        child: Text(coord),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class LatLng {
  final double lat;
  final double lon;
  LatLng(this.lat, this.lon);

  @override
  String toString() => '($lat, $lon)';
}
