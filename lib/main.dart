import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gm;
import 'dart:math';

void main() {
  runApp(
    MaterialApp(
      home: cheng114finalHome(),
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true, // 如果你使用 Material 3 的元件
      ),
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
  String _address = '';
  String _explanation = '';
  gm.GoogleMapController? _mapController;
  Set<gm.Marker> _markers = {};
  Set<gm.Polyline> _polylines = {};

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  void _addAddressField() {
    setState(() {
      _controllers.add(TextEditingController());
      _coordinates.add('');
    });
  }

  //刪掉地址欄
  void _removeAddressField(int index) {
    setState(() {
      if (_controllers.length > 1) {
        _controllers.removeAt(index);
        _coordinates.removeAt(index);
      }
    });
  }

  void _getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return; // 跳對話框提示
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission != LocationPermission.whileInUse &&
          permission != LocationPermission.always) {
        return; // 使用者拒絕
      }
    }

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

      //找地址
      try {
        List<Location> locations = await locationFromAddress(address);
        if (locations.isNotEmpty) {
          Location loc = locations.first;
          results.add('${loc.latitude},${loc.longitude}');
          coords.add(LatLng(loc.latitude, loc.longitude));
          addresses.add(address);
        } else {
          results.add('❗錯誤');
        }
      } catch (e) {
        results.add('❗錯誤：$e');
      }
    }

    setState(() {
      _coordinates = results;
      _latLngList = coords;
      _addressList = addresses;
      _markers = coords.asMap().entries.map((entry) {
        int index = entry.key;
        LatLng latLng = entry.value;
        // 建立一個 Marker
        return gm.Marker(
          markerId: gm.MarkerId('marker_$index'),
          position: gm.LatLng(latLng.lat, latLng.lon),
          infoWindow: gm.InfoWindow(title: addresses[index]),
        );
      }).toSet();
    });
  }

  void _solveTSPWithSteps() async {
    await _fetchCoordinates();
    _getCurrentLocation(); //跟用戶拿位置權限
    if (_latLngList.length < 3) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('請輸入至少三個有效地址才能計算最短路徑')));
      return;
    }

    final n = _latLngList.length; // 節點數量（即地址數量）
    final visited = List<bool>.filled(n, false); // 用來標記哪些節點已經拜訪過
    final path = <int>[]; // 暫存目前的拜訪路徑（以索引為單位）
    double best = double.infinity; // 初始化最短距離為無限大
    List<int> bestPath = []; // 儲存最佳（最短距離）路徑
    String asciiLog = ''; // 儲存 ASCII 格式的探索紀錄（用來顯示每次搜尋過程）

    void dfs(int current, double dist, int depth, String prefix) {
      if (depth == n) { // 如果已經走過所有節點（即完成一條巡迴）
        double back = _haversine(_latLngList[current], _latLngList[0]); // 計算從最後一點回到起點的距離
        double total = dist + back; // 計算總巡迴距離
        asciiLog +=
        '$prefix└ 回到起點 ${_addressList[0]} (+${back.toStringAsFixed(2)}) 總計=${total.toStringAsFixed(2)}\n'; // 紀錄這次路徑與總距離
        if (total < best) { // 如果這次的總距離比目前最佳還短，就更新最佳解
          best = total;
          bestPath = List<int>.from(path); // 儲存這條最佳路徑
        }
        return;
      }

      for (int i = 0; i < n; i++) { // 對所有節點進行嘗試
        if (!visited[i]) { // 如果這個節點還沒拜訪過
          visited[i] = true; // 標記為已拜訪
          path.add(i); // 加入目前路徑
          double d =
          path.length > 1
              ? _haversine(
            _latLngList[path[path.length - 2]],
            _latLngList[i],
          ) // 如果不是第一個點，則計算上一個點到目前點的距離
              : 0; // 如果是第一個點，不計距離
          asciiLog +=
          '$prefix├ 探索 ${_addressList[i]} (+${d.toStringAsFixed(2)})\n'; // 紀錄這次探索
          dfs(i, dist + d, depth + 1, prefix + '│  '); // 遞迴探索下一層（多加層級符號）
          visited[i] = false; // 回溯時標記為未拜訪
          path.removeLast(); // 移除最後一個節點（回溯）
        }
      }
    }

    visited[0] = true; // 將起點（index 0）標記為已拜訪，因為從這裡開始
    path.add(0); // 將起點加入目前路徑
    asciiLog += '[Start] ${_addressList[0]}\n'; // 記錄開始點的地址到 asciiLog
    dfs(0, 0, 1, ''); // 開始進行 DFS 探索，從第 0 點出發，距離為 0，深度為 1，縮排字串為空

    List<String> steps = []; // 儲存每一步的文字說明（例如 A ➡️ B = 2.34）
    List<gm.LatLng> polyPoints = []; // 儲存畫線用的路徑點（LatLng 格式）

    for (int i = 0; i < bestPath.length - 1; i++) { // 走訪最佳路徑中的每一對連續點
      double d = _haversine(
        _latLngList[bestPath[i]],
        _latLngList[bestPath[i + 1]],
      ); // 計算兩點之間的距離
      steps.add(
        '${_addressList[bestPath[i]]} ➡️ ${_addressList[bestPath[i + 1]]} = ${d.toStringAsFixed(2)}',
      ); // 加入一步步的移動描述文字
      polyPoints.add(gm.LatLng(_latLngList[bestPath[i]].lat, _latLngList[bestPath[i]].lon)); // 把目前點加入畫線的點列表
    }

    double d = _haversine(_latLngList[bestPath.last], _latLngList[0]); // 計算最後一點回到起點的距離
    steps.add(
      '${_addressList[bestPath.last]} ➡️ ${_addressList[0]} = ${d.toStringAsFixed(2)}',
    ); // 加入最後一段回起點的移動說明
    polyPoints.add(gm.LatLng(_latLngList[bestPath.last].lat, _latLngList[bestPath.last].lon)); // 加入最後一點的經緯度
    polyPoints.add(gm.LatLng(_latLngList[0].lat, _latLngList[0].lon)); // 加入回到起點的經緯度，完成封閉路線

    _explanation = '''使用 DFS（深度優先搜尋）+ 回溯法。
每次從起點出發，試走所有排列可能，記錄距離，找出最短。

1. 起點固定：第一筆地址當作起點。
2. 每次往下一個未訪問的點走，累積距離。
3. 一路走到底再回到起點，並記錄總距離。
4. 如果比目前最佳解還短，則更新最佳解。

整個過程會記錄成樹狀圖來幫助觀察遞迴過程與每一步的選擇。''';

    setState(() {
      _asciiTree = asciiLog; // 更新 ASCII 樹狀圖記錄（顯示 DFS 探索過程）
      _totalDistance = best.toStringAsFixed(2); // 更新總距離結果（取小數點後兩位）
      _distanceSteps = steps; // 更新逐步移動紀錄（例如：A ➡️ B = 3.21）
      _polylines = {
        gm.Polyline(
          polylineId: gm.PolylineId('route'),
          points: polyPoints,
          color: Colors.blue,
          width: 4,
        ),
      }; // 把這條線包成一個 Set，交給 GoogleMap 顯示路徑
    });
  }

  //弄一個對話框寫計算過程
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
    //算距離 但是是地表方式所以會比平面距更真
    const R = 6371; // 地球半徑（單位：公里）
    final dLat = _toRadians(p2.lat - p1.lat); // 緯度差轉為弧度
    final dLon = _toRadians(p2.lon - p1.lon); // 經度差轉為弧度
    final a = // Haversine 公式的核心部分（半弧長公式）
    pow(sin(dLat / 2), 2) +
        cos(_toRadians(p1.lat)) *
            cos(_toRadians(p2.lat)) *
            pow(sin(dLon / 2), 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a)); // 中心角（弧度）
    return R * c; // 地表距離（公里）
  }

  double _toRadians(double deg) => deg * pi / 180; // 將角度轉換為弧度（度數 × π ÷ 180）

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('4b1g0906 售貨員旅行解決器')), //標題
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
              child: Column(
                children: [
                  ListView.builder(
                    shrinkWrap: true,
                    physics: NeverScrollableScrollPhysics(),
                    itemCount: _controllers.length,
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(0, 8, 0, 0),
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
                  ..._distanceSteps.map( // 將每一步顯示為列表
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
                      '經緯度列表 (點一下拷貝單筆)',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  ..._coordinates.asMap().entries.map((entry) { //顯示經緯度列表
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
          ),
          SizedBox(
            height: 300,
            child: gm.GoogleMap( //地圖的部分
              initialCameraPosition: gm.CameraPosition(
                target: _latLngList.isNotEmpty
                    ? gm.LatLng(_latLngList[0].lat, _latLngList[0].lon)
                    : gm.LatLng(23.5, 121),
                zoom: 8,
              ),
              markers: _markers,
              polylines: _polylines,
              onMapCreated: (controller) => _mapController = controller,
              zoomGesturesEnabled: true,       // ✅ 開啟縮放手勢
              zoomControlsEnabled: true,       // ✅ 顯示放大縮小按鈕（Android 有用）
              scrollGesturesEnabled: true,     // ✅ 可平移
              tiltGesturesEnabled: true,       // ✅ 可傾斜
              rotateGesturesEnabled: false,     // ✅ 可旋轉
              myLocationEnabled: true,         // ✅ 顯示使用者目前位置
              myLocationButtonEnabled: true,
            ),
          ),
        ],
      ),
    );
  }
}

class LatLng {
  final double lat;
  final double lon;
  LatLng(this.lat, this.lon);

  @override
  String toString() => '($lat, $lon)'; // 重新定義 toString，讓列印時變成 (緯度, 經度) 的格式
}