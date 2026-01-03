import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class Crop {
  final String id;
  final String name;
  final String type;
  final String? plantedDate;
  final String? area;

  Crop({
    required this.id,
    required this.name,
    required this.type,
    this.plantedDate,
    this.area,
  });

  factory Crop.fromJson(Map<String, dynamic> json) {
    return Crop(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      type: json['type'] ?? '',
      plantedDate: json['plantedDate'] ?? json['planted_date'],
      area: json['area'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'plantedDate': plantedDate,
      'area': area,
    };
  }
}

class CropCache {
  static final Map<String, List<Crop>> _memoryCache = {};
  static final Map<String, bool> _isLoaded = {};
  static const String _storagePrefix = 'crops_cache_';
  static const String _loadedPrefix = 'crops_loaded_';
  static const String _timestampPrefix = 'crops_timestamp_';

  // Initialize cache from persistent storage
  static Future<void> initializeCache(String userId) async {
    if (_isLoaded[userId] == true) return; // Already loaded

    final prefs = await SharedPreferences.getInstance();
    final cachedData = prefs.getString('$_storagePrefix$userId');
    final isLoaded = prefs.getBool('$_loadedPrefix$userId') ?? false;

    if (cachedData != null && isLoaded) {
      try {
        final List<dynamic> jsonList = json.decode(cachedData);
        final crops = jsonList.map((json) => Crop.fromJson(json)).toList();
        _memoryCache[userId] = crops;
        _isLoaded[userId] = true;

        if (kDebugMode) {
          final timestamp = prefs.getInt('$_timestampPrefix$userId') ?? 0;
          final lastSaved = DateTime.fromMillisecondsSinceEpoch(timestamp);
          print('Cache loaded from storage. Last saved: $lastSaved');
        }
      } catch (e) {
        if (kDebugMode) {
          print('Error loading cache from storage: $e');
        }
        // Clear corrupted data
        await clearPersistentCache(userId);
      }
    }
  }

  // Check if data is already loaded
  static bool isDataLoaded(String userId) {
    return _isLoaded[userId] == true && _memoryCache.containsKey(userId);
  }

  // Get cached crops (from memory first, then try loading from storage)
  static Future<List<Crop>?> getCachedCrops(String userId) async {
    // Try memory cache first
    if (isDataLoaded(userId)) {
      return _memoryCache[userId];
    }

    // Try loading from persistent storage
    await initializeCache(userId);
    return _memoryCache[userId];
  }

  // Set cached crops and save to persistent storage
  static Future<void> setCachedCrops(String userId, List<Crop> crops) async {
    _memoryCache[userId] = crops;
    _isLoaded[userId] = true;

    // Save to persistent storage
    await _saveToPersistentStorage(userId, crops);
  }

  // Save to SharedPreferences
  static Future<void> _saveToPersistentStorage(
    String userId,
    List<Crop> crops,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = json.encode(
        crops.map((crop) => crop.toJson()).toList(),
      );

      await prefs.setString('$_storagePrefix$userId', jsonString);
      await prefs.setBool('$_loadedPrefix$userId', true);
      await prefs.setInt(
        '$_timestampPrefix$userId',
        DateTime.now().millisecondsSinceEpoch,
      );

      if (kDebugMode) {
        print('Cache saved to persistent storage for user: $userId');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error saving to persistent storage: $e');
      }
    }
  }

  // Clear all cache (memory + storage)
  static Future<void> clearAllCache(String userId) async {
    _memoryCache.remove(userId);
    _isLoaded.remove(userId);
    await clearPersistentCache(userId);
  }

  // Clear only persistent storage
  static Future<void> clearPersistentCache(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('$_storagePrefix$userId');
      await prefs.remove('$_loadedPrefix$userId');
      await prefs.remove('$_timestampPrefix$userId');
    } catch (e) {
      if (kDebugMode) {
        print('Error clearing persistent cache: $e');
      }
    }
  }

  // Force refresh - clears all cache and forces reload
  static Future<void> forceRefresh(String userId) async {
    await clearAllCache(userId);
  }

  // Add crop to cache (memory + storage)
  static Future<void> addCropToCache(String userId, Crop crop) async {
    if (isDataLoaded(userId)) {
      _memoryCache[userId]?.add(crop);
      await _saveToPersistentStorage(userId, _memoryCache[userId]!);
    }
  }

  // Remove crop from cache (memory + storage)
  static Future<void> removeCropFromCache(String userId, String cropId) async {
    if (isDataLoaded(userId)) {
      _memoryCache[userId]?.removeWhere((crop) => crop.id == cropId);
      if (_memoryCache[userId] != null) {
        await _saveToPersistentStorage(userId, _memoryCache[userId]!);
      }
    }
  }

  // Update specific crop in cache (memory + storage)
  static Future<void> updateCropInCache(
    String userId,
    String cropId,
    Crop updatedCrop,
  ) async {
    if (isDataLoaded(userId)) {
      final crops = _memoryCache[userId];
      if (crops != null) {
        final index = crops.indexWhere((crop) => crop.id == cropId);
        if (index != -1) {
          crops[index] = updatedCrop;
          await _saveToPersistentStorage(userId, crops);
        }
      }
    }
  }

  // Get cache info for debugging
  static Future<Map<String, dynamic>> getCacheInfo(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final timestamp = prefs.getInt('$_timestampPrefix$userId') ?? 0;
    final isLoaded = prefs.getBool('$_loadedPrefix$userId') ?? false;
    final hasMemoryCache = _memoryCache.containsKey(userId);
    final cropCount = _memoryCache[userId]?.length ?? 0;

    return {
      'isLoaded': isLoaded,
      'hasMemoryCache': hasMemoryCache,
      'cropCount': cropCount,
      'lastSaved':
          timestamp > 0 ? DateTime.fromMillisecondsSinceEpoch(timestamp) : null,
      'cacheSize': prefs.getString('$_storagePrefix$userId')?.length ?? 0,
    };
  }
}

class PlantationManagementPage extends StatefulWidget {
  final String userId;

  const PlantationManagementPage({super.key, required this.userId});

  @override
  State<PlantationManagementPage> createState() =>
      _PlantationManagementPageState();
}

class _PlantationManagementPageState extends State<PlantationManagementPage> {
  List<Crop> crops = [];
  bool isLoading = false;
  String errorMessage = '';
  bool isOnline = true;

  String get userId => widget.userId;

  String dailySuggestion = 'Loading...';

  String suggestionHeading = 'Today\'s Suggestion';

  @override
  void initState() {
    super.initState();
    fetchDailySuggestion();
    loadCrops();
  }

  Future<void> loadCrops() async {
    // 1. Initialize cache
    await CropCache.initializeCache(userId);

    // 2. Load cached data first (Fast UI)
    final cachedCrops = await CropCache.getCachedCrops(userId);
    if (cachedCrops != null && cachedCrops.isNotEmpty) {
      if (mounted) {
        setState(() {
          crops = cachedCrops;
        });
      }
      if (kDebugMode) {
        print(
          'Loaded ${cachedCrops.length} crops from cache. Fetching fresh data in background...',
        );
      }
    } else {
      if (mounted) setState(() => isLoading = true);
    }

    await fetchCrops();
  }

  // Method to force refresh from API
  Future<void> refreshCrops() async {
    await CropCache.forceRefresh(userId);
    await fetchCrops();
  }

  Future<void> fetchCrops() async {
    if (!mounted) return; // 1. Check at start

    try {
      // Only show loading if we don't have data yet
      if (crops.isEmpty) {
        setState(() {
          isLoading = true;
          errorMessage = '';
          isOnline = true;
        });
      }

      if (userId.isEmpty ||
          userId == '0' ||
          userId == 'null' ||
          userId == 'undefined') {
        if (!mounted) return;
        setState(() {
          errorMessage = 'Invalid user ID';
          isLoading = false;
        });
        return;
      }

      final response = await http
          .get(
            Uri.parse(
              'https://agrihive-server91.onrender.com/getCrops?userId=$userId',
            ),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(Duration(seconds: 30));

      if (!mounted) return; // 2. CRITICAL CHECK after HTTP await

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);

        if (responseData.containsKey('crops')) {
          final List<dynamic> cropsData =
              responseData['crops'] as List<dynamic>;
          final cropsList =
              cropsData.map((json) => Crop.fromJson(json)).toList();

          // Cache the results with persistent storage
          await CropCache.setCachedCrops(userId, cropsList);

          if (!mounted) return; // 3. CRITICAL CHECK after Cache await

          setState(() {
            crops = cropsList;
            isLoading = false;
          });

          if (kDebugMode) {
            print('Fetched and cached ${cropsList.length} crops from API');
          }
        } else {
          await CropCache.setCachedCrops(userId, []);

          if (!mounted) return; // 4. CRITICAL CHECK

          setState(() {
            crops = [];
            isLoading = false;
          });
        }
      } else if (response.statusCode == 400) {
        final Map<String, dynamic> errorData = json.decode(response.body);
        setState(() {
          errorMessage = errorData['error'] ?? 'Invalid request';
          isLoading = false;
        });
      } else {
        setState(() {
          errorMessage = 'Failed to load crops: ${response.statusCode}';
          isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return; // 5. Check in catch block before UI updates

      setState(() {
        errorMessage = 'Network error: Unable to connect to server';
        isLoading = false;
        isOnline = false;
      });

      // Try to load from cache when offline
      final cachedCrops = await CropCache.getCachedCrops(userId);

      if (!mounted) return; // 6. Check after async cache retrieval

      if (cachedCrops != null && cachedCrops.isNotEmpty) {
        setState(() {
          crops = cachedCrops;
          errorMessage = 'Showing cached data (Offline)';
        });
      }
    }
  }

  Future<bool> addCropsToDatabase(
    String userId,
    List<Map<String, dynamic>> cropData,
  ) async {
    const String apiUrl = "https://agrihive-server91.onrender.com/addCrop";

    try {
      final response = await http
          .post(
            Uri.parse(apiUrl),
            headers: {"Content-Type": "application/json"},
            body: jsonEncode({"userId": userId, "cropData": cropData}),
          )
          .timeout(Duration(seconds: 30));

      if (response.statusCode == 200) {
        final responseBody = jsonDecode(response.body);
        final success =
            responseBody["message"]?.toString().toLowerCase().contains(
              "success",
            ) ??
            false;

        if (success) {
          // Refresh data after successful add to get server-generated IDs
          await refreshCrops();
        }

        return success;
      } else {
        if (kDebugMode) {
          print("Server error: ${response.statusCode}");
        }
        return false;
      }
    } catch (e) {
      if (kDebugMode) {
        print("Error occurred: $e");
      }
      return false;
    }
  }

  Future<bool> deleteCropFromDatabase(String userId, String cropId) async {
    final url = Uri.parse('https://agrihive-server91.onrender.com/deleteCrop');

    try {
      final response = await http
          .delete(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'userId': userId, 'cropId': cropId}),
          )
          .timeout(Duration(seconds: 30));

      if (response.statusCode == 200) {
        // Remove from cache and update UI immediately
        await CropCache.removeCropFromCache(userId, cropId);
        final updatedCrops = await CropCache.getCachedCrops(userId) ?? [];
        setState(() {
          crops = updatedCrops;
        });
        return true;
      } else {
        if (kDebugMode) {
          print('Failed to delete: ${response.body}');
        }
        return false;
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error deleting crop: $e');
      }
      return false;
    }
  }

  Future<bool> updateCropInDatabase(
    String userId,
    String cropId,
    Map<String, dynamic> cropData,
  ) async {
    final url = Uri.parse('https://agrihive-server91.onrender.com/updateCrop');

    try {
      final response = await http
          .put(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'userId': userId,
              'cropId': cropId,
              'cropData': cropData,
            }),
          )
          .timeout(Duration(seconds: 30));

      if (response.statusCode == 200) {
        // Update cache and UI immediately
        final updatedCrop = Crop.fromJson({'id': cropId, ...cropData});
        await CropCache.updateCropInCache(userId, cropId, updatedCrop);

        // Refresh UI with updated cache
        final updatedCrops = await CropCache.getCachedCrops(userId) ?? [];
        setState(() {
          crops = updatedCrops;
        });

        return true;
      } else {
        if (kDebugMode) {
          print('Failed to update: ${response.body}');
        }
        return false;
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error updating crop: $e');
      }
      return false;
    }
  }

  Future<void> fetchDailySuggestion() async {
    if (!mounted) return; // 1. Check at start

    setState(() => isLoading = true);

    try {
      final response = await http.get(
        Uri.parse(
          'https://agrihive-server91.onrender.com/getDailySuggestion?userId=$userId',
        ),
        headers: {'Accept': 'application/json', 'User-Agent': 'Flutter App'},
      );

      if (!mounted) return; // 2. CRITICAL CHECK after await

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          suggestionHeading = data['suggestion']['heading'] ?? 'Daily Tip';
          dailySuggestion =
              data['suggestion']['body'] ?? 'No suggestion available';
          isLoading = false;
        });
      } else if (response.statusCode == 404) {
        final error = json.decode(response.body)['error'];
        setState(() {
          suggestionHeading = 'No Crops Found';
          dailySuggestion = error ?? 'No crops added yet. Please add crops.';
          isLoading = false;
        });
      } else {
        setState(() {
          suggestionHeading = 'Error';
          dailySuggestion = 'Unexpected Error (${response.statusCode})';
          isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return; // 3. Check in catch block

      setState(() {
        suggestionHeading = 'Network Error';
        dailySuggestion = 'Could not fetch suggestions. Please try again.';
        isLoading = false;
      });
    }
  }

  void showAddCropDialog(BuildContext context, String userId) {
    final TextEditingController nameController = TextEditingController();
    final TextEditingController areaController = TextEditingController();
    DateTime? selectedDate;

    showDialog(
      context: context,
      builder: (context) {
        return Center(
          child: Material(
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: EdgeInsets.all(24),
              width: 300,
              child: StatefulBuilder(
                builder: (context, setState) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Add Crop',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 16),
                      TextField(
                        controller: nameController,
                        decoration: InputDecoration(labelText: 'Crop Name'),
                      ),
                      SizedBox(height: 12),
                      TextField(
                        controller: areaController,
                        decoration: InputDecoration(
                          labelText: 'Area (in acres)',
                        ),
                        keyboardType: TextInputType.number,
                      ),
                      SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            selectedDate == null
                                ? 'Select Date'
                                : '${selectedDate!.toLocal()}'.split(' ')[0],
                          ),
                          TextButton(
                            onPressed: () async {
                              DateTime? picked = await showDatePicker(
                                context: context,
                                initialDate: DateTime.now(),
                                firstDate: DateTime(2000),
                                lastDate: DateTime(2100),
                              );
                              if (picked != null) {
                                setState(() {
                                  selectedDate = picked;
                                });
                              }
                            },
                            child: Text('Pick Date'),
                          ),
                        ],
                      ),
                      SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () async {
                          final String name = nameController.text.trim();
                          final String area = areaController.text.trim();
                          final String? date =
                              selectedDate?.toIso8601String().split("T").first;

                          if (name.isEmpty || area.isEmpty || date == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Please fill all fields')),
                            );
                            return;
                          }

                          final crop = {
                            "name": name,
                            "area": int.tryParse(area) ?? 0,
                            "plantedDate": date,
                          };

                          bool success = await addCropsToDatabase(userId, [
                            crop,
                          ]);
                          if (success) {
                            Navigator.of(context).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Crop added successfully!'),
                              ),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Failed to add crop.')),
                            );
                          }
                        },
                        child: Text('Submit'),
                      ),
                      SizedBox(height: 8),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text('Cancel'),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  void showUpdateDialog(BuildContext context, String userId, Map crop) {
    final nameController = TextEditingController(text: crop['name']);
    final areaController = TextEditingController(
      text: crop['area']?.toString(),
    );
    DateTime? selectedDate = DateTime.tryParse(crop['plantedDate'] ?? '');

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Update Crop'),
            content: StatefulBuilder(
              builder: (context, setState) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: InputDecoration(labelText: 'Crop Name'),
                    ),
                    TextField(
                      controller: areaController,
                      decoration: InputDecoration(labelText: 'Area (in acres)'),
                      keyboardType: TextInputType.number,
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          selectedDate == null
                              ? 'Select Date'
                              : selectedDate!.toIso8601String().split('T')[0],
                        ),
                        TextButton(
                          onPressed: () async {
                            DateTime? picked = await showDatePicker(
                              context: context,
                              initialDate: selectedDate ?? DateTime.now(),
                              firstDate: DateTime(2000),
                              lastDate: DateTime(2100),
                            );
                            if (picked != null) {
                              setState(() {
                                selectedDate = picked;
                              });
                            }
                          },
                          child: Text('Pick Date'),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final name = nameController.text.trim();
                  final area = int.tryParse(areaController.text.trim()) ?? 0;
                  final date = selectedDate?.toIso8601String().split('T').first;

                  final updatedData = {
                    'name': name,
                    'area': area,
                    'plantedDate': date,
                  };

                  final success = await updateCropInDatabase(
                    userId,
                    crop['id'],
                    updatedData,
                  );
                  Navigator.pop(context);

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        success
                            ? 'Crop updated successfully'
                            : 'Failed to update crop',
                      ),
                    ),
                  );

                  if (success) {
                    // Refresh from cache (which was invalidated)
                    await loadCrops();
                  }
                },
                child: Text('Update'),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/plantation.jpg'),
            fit: BoxFit.cover,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Custom AppBar with back button and Plantation text
              Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.green[700],
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Center(
                        child: Text(
                          'Plantation',
                          style: TextStyle(
                            fontFamily: 'lufga',
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              Expanded(
                flex: 3,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 8,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Suggestion Box
                      Expanded(
                        flex: 2,
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color.fromARGB(51, 5, 74, 41),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Color.fromARGB(127, 76, 175, 80),
                              width: 1,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Heading
                              Row(
                                children: [
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      suggestionHeading,
                                      style: const TextStyle(
                                        fontFamily: 'lufga',
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 2,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 5),
                              Container(
                                height: 1,
                                color: const Color.fromARGB(100, 76, 175, 80),
                              ),
                              const SizedBox(height: 8),
                              // Content
                              Expanded(
                                child:
                                    isLoading
                                        ? const Center(
                                          child: Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              CircularProgressIndicator(
                                                color: Colors.white,
                                                strokeWidth: 2,
                                              ),
                                              SizedBox(height: 12),
                                              Text(
                                                'Loading...',
                                                style: TextStyle(
                                                  color: Colors.white70,
                                                  fontSize: 14,
                                                ),
                                              ),
                                            ],
                                          ),
                                        )
                                        : SingleChildScrollView(
                                          physics: BouncingScrollPhysics(),
                                          child: Text(
                                            dailySuggestion.isNotEmpty
                                                ? dailySuggestion
                                                : 'No suggestion available',
                                            style: const TextStyle(
                                              fontFamily: 'lufga',
                                              color: Colors.white,
                                              fontSize: 10,
                                              height: 1.4,
                                              fontWeight: FontWeight.w400,
                                            ),
                                          ),
                                        ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(width: 12),

                      // Random Icon Box
                      Expanded(
                        flex: 1,
                        child: Column(
                          children: [
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color.fromARGB(48, 5, 74, 41),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Color.fromARGB(127, 76, 175, 80),
                                    width: 1,
                                  ),
                                ),
                                child: const Center(
                                  child: Icon(
                                    Icons.shuffle,
                                    color: Colors.white70,
                                    size: 32,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Random',
                              style: TextStyle(
                                color: Colors.white,
                                fontFamily: 'lufga',
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Second division - Bottom section for database data (2/3 of page)
              Expanded(
                flex: 7,
                child: Container(
                  width: double.infinity,
                  margin: EdgeInsets.all(0),
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Color.fromRGBO(255, 255, 255, 0),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Padding(
                            padding: EdgeInsets.only(left: 10, top: 0),
                            child: Text(
                              'My Crops',
                              style: TextStyle(
                                fontSize: 20,
                                fontFamily: 'lufga',
                                fontWeight: FontWeight.w500,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.refresh, color: Colors.white),
                            onPressed: fetchCrops,
                          ),
                        ],
                      ),
                      SizedBox(height: 2),
                      Expanded(child: buildCropsList()),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: Container(
        margin: const EdgeInsets.only(bottom: 100), // Adjust height as needed
        child: FloatingActionButton(
          onPressed: () {
            showAddCropDialog(context, userId);
          },
          backgroundColor: Colors.green[700],
          child: Icon(Icons.add, color: Colors.white, size: 30),
        ),
      ),
    );
  }

  Widget buildCropsList() {
    if (isLoading) {
      return Center(child: CircularProgressIndicator());
    }

    if (errorMessage.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(errorMessage),
            ElevatedButton(onPressed: fetchCrops, child: Text('Retry')),
          ],
        ),
      );
    }

    if (crops.isEmpty) {
      return Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.grass,
                color: const Color.fromARGB(255, 221, 255, 222),
                size: 36,
              ),
              SizedBox(height: 8),
              Text(
                'No crops found',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: const Color.fromARGB(255, 255, 255, 255),
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Start by adding your first crop to get suggestions and tracking!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: const Color.fromARGB(255, 255, 255, 255),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: fetchCrops,
      child: ListView.builder(
        itemCount: crops.length,
        itemBuilder: (context, index) {
          final crop = crops[index];
          return Padding(
            padding: const EdgeInsets.symmetric(
              vertical: 5,
            ), // No horizontal padding

            child: GestureDetector(
              onLongPress: () {
                showDialog(
                  context: context,
                  builder:
                      (context) => AlertDialog(
                        title: Text('Crop Info'),
                        content: Text(
                          'Name: ${crop.name}\n'
                          'Area: ${crop.area ?? "Unknown"} acres\n'
                          'Sowed on: ${crop.plantedDate ?? "Unknown"}',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: Text('Close'),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.pop(context); // close current dialog
                              showUpdateDialog(context, userId, {
                                'id': crop.id,
                                'name': crop.name,
                                'area': crop.area,
                                'plantedDate': crop.plantedDate,
                              });
                            },
                            child: Text('Update'),
                          ),
                        ],
                      ),
                );
              },
              child: AnimatedContainer(
                duration: Duration(milliseconds: 150),
                curve: Curves.easeInOut,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Card(
                      color: Color.fromARGB(48, 5, 74, 41),
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(
                          color: Color.fromARGB(127, 76, 175, 80),
                          width: 1,
                        ),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        splashColor: const Color.fromARGB(
                          127,
                          76,
                          175,
                          80,
                        ).withOpacity(0.1),
                        highlightColor: const Color.fromARGB(
                          127,
                          76,
                          175,
                          80,
                        ).withOpacity(0.05),
                        onTap: () {
                          // Optional: Add tap functionality if needed
                        },
                        child: Container(
                          width: double.infinity, // Force full width
                          padding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.grass,
                                        color: Colors.white,
                                        size: 28,
                                      ),
                                      SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              crop.name,
                                              style: TextStyle(
                                                fontFamily: 'lufga',
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13,
                                              ),
                                            ),
                                            SizedBox(height: 3),
                                            Text(
                                              'Sowed on:',
                                              style: TextStyle(
                                                color: Colors.white70,
                                                fontSize: 9,
                                              ),
                                            ),
                                            Text(
                                              crop.plantedDate ?? "Unknown",
                                              style: TextStyle(
                                                color: Colors.white70,
                                                fontSize: 11,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Text(
                                        '${crop.area ?? "Unknown"} acres',
                                        style: TextStyle(
                                          color: Colors.yellow[500],
                                          fontFamily: 'lufga',
                                          fontSize: 11,
                                        ),
                                      ),
                                      IconButton(
                                        icon: Icon(
                                          Icons.delete,
                                          color: Colors.redAccent,
                                          size: 28,
                                        ),
                                        onPressed: () {
                                          // Handle deletion
                                          showDialog(
                                            context: context,
                                            builder: (context) {
                                              return AlertDialog(
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                ),
                                                title: Text('Delete Crop'),
                                                content: Text(
                                                  'Are you sure you want to delete ${crop.name}?',
                                                ),
                                                actions: [
                                                  TextButton(
                                                    onPressed: () {
                                                      Navigator.of(
                                                        context,
                                                      ).pop();
                                                    },
                                                    child: Text('Cancel'),
                                                  ),
                                                  TextButton(
                                                    onPressed: () async {
                                                      bool success =
                                                          await deleteCropFromDatabase(
                                                            userId,
                                                            crop.id,
                                                          );

                                                      Navigator.of(
                                                        context,
                                                      ).pop(); // Close the dialog first

                                                      ScaffoldMessenger.of(
                                                        context,
                                                      ).showSnackBar(
                                                        SnackBar(
                                                          content: Text(
                                                            success
                                                                ? 'Crop deleted successfully'
                                                                : 'Failed to delete crop',
                                                          ),
                                                        ),
                                                      );

                                                      if (success) {
                                                        fetchCrops();
                                                      }
                                                    },
                                                    child: Text(
                                                      'Delete',
                                                      style: TextStyle(
                                                        color: Colors.red,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              );
                                            },
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
