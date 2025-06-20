import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

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
}

class CropCache {
  static final Map<String, List<Crop>> _cache = {};
  static final Map<String, DateTime> _lastFetch = {};
  static const Duration _cacheExpiry = Duration(minutes: 15);

  static bool isCacheValid(String userId) {
    final lastFetch = _lastFetch[userId];
    if (lastFetch == null) return false;
    return DateTime.now().difference(lastFetch) < _cacheExpiry;
  }

  static List<Crop>? getCachedCrops(String userId) {
    if (isCacheValid(userId)) {
      return _cache[userId];
    }
    return null;
  }

  static void setCachedCrops(String userId, List<Crop> crops) {
    _cache[userId] = crops;
    _lastFetch[userId] = DateTime.now();
  }

  static void invalidateCache(String userId) {
    _cache.remove(userId);
    _lastFetch.remove(userId);
  }
}

class PlantationManagementPage extends StatefulWidget {
  final String userId;

  const PlantationManagementPage({
    super.key,
    required this.userId,
  });

  @override
  State<PlantationManagementPage> createState() =>
      _PlantationManagementPageState();
}

class _PlantationManagementPageState extends State<PlantationManagementPage> {
  List<Crop> crops = [];
  bool isLoading = true;
  String errorMessage = '';

  String get userId => widget.userId;

  @override
  void initState() {
    super.initState();
    loadCrops();
  }

  Future<void> loadCrops() async {
    // Try cache first
    final cachedCrops = CropCache.getCachedCrops(userId);
    if (cachedCrops != null) {
      setState(() {
        crops = cachedCrops;
        isLoading = false;
      });
      return;
    }

    // Fetch from API if cache miss
    await fetchCrops();
  }

  Future<void> fetchCrops() async {
    try {
      setState(() {
        isLoading = true;
        errorMessage = '';
      });

      if (userId.isEmpty || userId == '0' || userId == 'null' || userId == 'undefined') {
        setState(() {
          errorMessage = 'Invalid user ID';
          isLoading = false;
        });
        return;
      }

      final response = await http.get(
        Uri.parse('https://agrihive-server91.onrender.com/getCrops?userId=$userId'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);

        if (responseData.containsKey('crops')) {
          final List<dynamic> cropsData = responseData['crops'] as List<dynamic>;
          final cropsList = cropsData.map((json) => Crop.fromJson(json)).toList();
          
          // Cache the results
          CropCache.setCachedCrops(userId, cropsList);
          
          setState(() {
            crops = cropsList;
            isLoading = false;
          });
        } else {
          setState(() {
            crops = [];
            isLoading = false;
          });
          CropCache.setCachedCrops(userId, []);
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
      setState(() {
        errorMessage = 'Network error: Unable to connect to server';
        isLoading = false;
      });
      if (kDebugMode) {
        print('Error fetching crops: $e');
      }
    }
  }

  Future<bool> addCropsToDatabase(String userId, List<Map<String, dynamic>> cropData) async {
    const String apiUrl = "https://agrihive-server91.onrender.com/addCrop";

    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"userId": userId, "cropData": cropData}),
      );

      if (response.statusCode == 200) {
        final responseBody = jsonDecode(response.body);
        final success = responseBody["message"]?.toString().toLowerCase().contains("success") ?? false;
        
        if (success) {
          // Invalidate cache on successful add
          CropCache.invalidateCache(userId);
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
      final response = await http.delete(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'userId': userId, 'cropId': cropId}),
      );

      if (response.statusCode == 200) {
        // Invalidate cache on successful delete
        CropCache.invalidateCache(userId);
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

  Future<bool> updateCropInDatabase(String userId, String cropId, Map<String, dynamic> cropData) async {
    final url = Uri.parse('https://agrihive-server91.onrender.com/updateCrop');

    try {
      final response = await http.put(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId': userId,
          'cropId': cropId,
          'cropData': cropData,
        }),
      );

      if (response.statusCode == 200) {
        // Invalidate cache on successful update
        CropCache.invalidateCache(userId);
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
                      Text('Add Crop', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      SizedBox(height: 16),
                      TextField(controller: nameController, decoration: InputDecoration(labelText: 'Crop Name')),
                      SizedBox(height: 12),
                      TextField(
                        controller: areaController,
                        decoration: InputDecoration(labelText: 'Area (in acres)'),
                        keyboardType: TextInputType.number,
                      ),
                      SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(selectedDate == null ? 'Select Date' : '${selectedDate!.toLocal()}'.split(' ')[0]),
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
                          final String? date = selectedDate?.toIso8601String().split("T").first;

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

                          bool success = await addCropsToDatabase(userId, [crop]);
                          if (success) {
                            Navigator.of(context).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Crop added successfully!')),
                            );
                            // Refresh from cache (which was invalidated)
                            await loadCrops();
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
    final areaController = TextEditingController(text: crop['area']?.toString());
    DateTime? selectedDate = DateTime.tryParse(crop['plantedDate'] ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Update Crop'),
        content: StatefulBuilder(
          builder: (context, setState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameController, decoration: InputDecoration(labelText: 'Crop Name')),
                TextField(
                  controller: areaController,
                  decoration: InputDecoration(labelText: 'Area (in acres)'),
                  keyboardType: TextInputType.number,
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(selectedDate == null ? 'Select Date' : selectedDate!.toIso8601String().split('T')[0]),
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

              final success = await updateCropInDatabase(userId, crop['id'], updatedData);
              Navigator.pop(context);

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(success ? 'Crop updated successfully' : 'Failed to update crop'),
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
                            fontSize: 25,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // First division - Show current user info
              Expanded(
                flex: 2,
                child: SizedBox(
                  width: double.infinity,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: Container(
                                  margin: EdgeInsets.only(
                                    left: 16,
                                    top: 8,
                                    bottom: 8,
                                    right: 8,
                                  ),
                                  padding: EdgeInsets.all(10),
                                  height:
                                      double
                                          .infinity, // ⬅️ This makes the box stretch to max height
                                  decoration: BoxDecoration(
                                    color: Color.fromARGB(51, 5, 74, 41),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: Color.fromARGB(127, 76, 175, 80),
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment
                                            .start, // Optional: center the text horizontally
                                    crossAxisAlignment:
                                        CrossAxisAlignment
                                            .start, // Optional: center the text vertically
                                    children: [
                                      Text(
                                        'Todays Suggestion',
                                        style: TextStyle(
                                          fontFamily: 'lufga',
                                          color: Colors.white,
                                          fontSize: 20,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              Expanded(
                                flex: 1,
                                child: Column(
                                  children: [
                                    Expanded(
                                      child: Container(
                                        margin: EdgeInsets.only(
                                          right: 16,
                                          left: 8,
                                          top: 8,
                                          bottom: 8,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Color.fromARGB(48, 5, 74, 41),
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                          border: Border.all(
                                            color: Color.fromARGB(
                                              127,
                                              76,
                                              175,
                                              80,
                                            ),
                                            width: 1,
                                          ),
                                        ),
                                      ),
                                    ),
                                    Padding(
                                      padding: EdgeInsets.only(bottom: 8),
                                      child: Text(
                                        'Random',
                                        style: TextStyle(color: Colors.white),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
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
                                fontSize: 25,
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
      return Center(child: Text('No crops found for $userId'));
    }

    return RefreshIndicator(
      onRefresh: fetchCrops,
      child: ListView.builder(
        itemCount: crops.length,
        itemBuilder: (context, index) {
          final crop = crops[index];
          return Padding(
            padding: const EdgeInsets.symmetric(
              vertical: 8,
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
                                        size: 35,
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
                                                fontSize: 18,
                                              ),
                                            ),
                                            SizedBox(height: 4),
                                            Text(
                                              'Sowed on:',
                                              style: TextStyle(
                                                color: Colors.white70,
                                                fontSize: 12,
                                              ),
                                            ),
                                            Text(
                                              crop.plantedDate ?? "Unknown",
                                              style: TextStyle(
                                                color: Colors.white70,
                                                fontSize: 15,
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
                                        ),
                                      ),
                                      IconButton(
                                        icon: Icon(
                                          Icons.delete,
                                          color: Colors.redAccent,
                                          size: 35,
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

 