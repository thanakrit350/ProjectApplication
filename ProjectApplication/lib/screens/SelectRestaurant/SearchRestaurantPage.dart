import 'dart:async';
import 'package:flutter/material.dart';
import 'package:newproject/boxs/userlog.dart';
import 'package:newproject/controller/RestaurantController.dart';
import 'package:newproject/model/Restaurant.dart';
import 'package:newproject/screens/Restaurant/ViewRestaurantPage.dart';

class SearchRestaurantPage extends StatefulWidget {
  const SearchRestaurantPage({super.key});

  @override
  State<SearchRestaurantPage> createState() => _SearchRestaurantPageState();
}

class _SearchRestaurantPageState extends State<SearchRestaurantPage> {
  final _ctl = TextEditingController();
  final _scroll = ScrollController();

  final List<Restaurant> _items = [];
  bool _initialLoading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  int _page = 0;
  final int _size = 20;

  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _loadFirst();
    _scroll.addListener(() {
      if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 300) {
        _loadNext();
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scroll.dispose();
    _ctl.dispose();
    super.dispose();
  }

  Future<void> _loadFirst() async {
    _items.clear();
    _page = 0;
    _hasMore = true;
    setState(() => _initialLoading = true);
    await _loadNext();
    if (mounted) setState(() => _initialLoading = false);
  }

  Future<void> _loadNext() async {
    if (_loadingMore || !_hasMore) return;
    _loadingMore = true;
    setState(() {});
    try {
      final page = await RestaurantController().fetchPaged(
        q: _ctl.text.trim(),
        page: _page,
        size: _size,
      );
      _items.addAll(page.items);
      _hasMore = !page.last;
      _page += 1;
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('โหลดข้อมูลล้มเหลว: $e')),
      );
    } finally {
      _loadingMore = false;
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ค้นหาร้านอาหาร'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _ctl,
              decoration: InputDecoration(
                hintText: 'ค้นหาร้าน / คำอธิบาย / จังหวัด ฯลฯ',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.grey[100],
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (t) {
                _debounce?.cancel();
                _debounce = Timer(const Duration(milliseconds: 400), _loadFirst);
              },
            ),
          ),
          Expanded(
            child: _initialLoading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _loadFirst,
                    child: ListView.separated(
                      controller: _scroll,
                      itemCount: _items.length + (_hasMore ? 1 : 0),
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        if (i >= _items.length) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: Center(child: CircularProgressIndicator(strokeWidth: 2.5)),
                          );
                        }
                        final r = _items[i];
                        return ListTile(
                          leading: const Icon(Icons.location_on, color: Colors.red),
                          title: Text(
                            r.restaurantName ?? '-',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            '${r.subdistrict ?? ''} ${r.district ?? ''} ${r.province ?? ''}\n${r.latitude ?? ''}, ${r.longitude ?? ''}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ViewRestaurantPage(
                                  restaurant: r,
                                  isLoggedIn: UserLog().isLoggedIn,
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
