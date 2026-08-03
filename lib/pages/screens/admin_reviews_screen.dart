import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../services/api_service.dart';

class AdminReviewsScreen extends StatefulWidget {
  const AdminReviewsScreen({super.key});

  @override
  State<AdminReviewsScreen> createState() => _AdminReviewsScreenState();
}

class _AdminReviewsScreenState extends State<AdminReviewsScreen> {
  final ApiService _apiService = ApiService();
  List<Map<String, dynamic>> _allReviews = [];
  List<Map<String, dynamic>> _filteredReviews = [];
  bool _isLoading = true;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadReviews();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadReviews() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final reviews = await _apiService.fetchAllReviews();
      if (mounted) {
        setState(() {
          _allReviews = reviews;
          _filterReviews(_searchQuery);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading reviews: $e')),
        );
      }
    }
  }

  void _filterReviews(String query) {
    _searchQuery = query.toLowerCase().trim();
    if (_searchQuery.isEmpty) {
      _filteredReviews = List.from(_allReviews);
    } else {
      _filteredReviews = _allReviews.where((rev) {
        final productName = (rev['productName'] ?? '').toString().toLowerCase();
        final productId = (rev['productId'] ?? '').toString().toLowerCase();
        final userEmail = (rev['userEmail'] ?? '').toString().toLowerCase();
        final userName = (rev['userName'] ?? '').toString().toLowerCase();
        final comment = (rev['comment'] ?? '').toString().toLowerCase();

        return productName.contains(_searchQuery) ||
            productId.contains(_searchQuery) ||
            userEmail.contains(_searchQuery) ||
            userName.contains(_searchQuery) ||
            comment.contains(_searchQuery);
      }).toList();
    }
  }

  Future<void> _confirmDeleteReview(Map<String, dynamic> review) async {
    final String reviewId = review['id'] ?? '';
    final String userName = review['userName'] ?? review['userEmail'] ?? 'User';

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red),
            SizedBox(width: 8),
            Text('Delete Review'),
          ],
        ),
        content: Text('Are you sure you want to delete the review by "$userName"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() {
        _isLoading = true;
      });

      final bool success = await _apiService.deleteReview(reviewId);
      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Review deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
          await _loadReviews();
        } else {
          setState(() {
            _isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to delete review'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _showImageDialog(String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            InteractiveViewer(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.contain,
                  placeholder: (context, url) => const SizedBox(
                    height: 200,
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  errorWidget: (context, url, error) => const Icon(Icons.error, color: Colors.white, size: 50),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 28),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  int parseIntSafe(dynamic val) {
    if (val is int) return val;
    if (val is String) return int.tryParse(val) ?? 5;
    return 5;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Product Reviews Management',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.blue[800],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadReviews,
          ),
        ],
      ),
      body: Column(
        children: [
          // Search & Count Bar
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.blue[50],
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  onChanged: (val) {
                    setState(() {
                      _filterReviews(val);
                    });
                  },
                  decoration: InputDecoration(
                    hintText: 'Search by product name, email, or comment...',
                    prefixIcon: const Icon(Icons.search, color: Colors.blue),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _filterReviews('');
                              });
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.blue[200]!),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total Reviews: ${_allReviews.length}',
                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue[900]),
                    ),
                    if (_searchQuery.isNotEmpty)
                      Text(
                        'Filtered: ${_filteredReviews.length}',
                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange[800]),
                      ),
                  ],
                ),
              ],
            ),
          ),

          // Reviews List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredReviews.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.rate_review_outlined, size: 64, color: Colors.grey[400]),
                            const SizedBox(height: 12),
                            Text(
                              _searchQuery.isNotEmpty ? 'No matching reviews found' : 'No customer reviews yet',
                              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadReviews,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _filteredReviews.length,
                          itemBuilder: (context, index) {
                            final rev = _filteredReviews[index];
                            final String productName = rev['productName'] ?? 'Product ID: ${rev['productId']}';
                            final String userName = rev['userName'] ?? 'Customer';
                            final String userEmail = rev['userEmail'] ?? '';
                            final int rating = parseIntSafe(rev['rating']);
                            final String comment = rev['comment'] ?? '';
                            final String? rawImg = rev['imageUrl'];
                            final String? imgUrl = (rawImg != null && rawImg.isNotEmpty)
                                ? ApiService.resolveUrl(rawImg)
                                : null;
                            final String dateStr = rev['createdAt'] ?? '';

                            String formattedDate = '';
                            if (dateStr.isNotEmpty) {
                              try {
                                String norm = dateStr;
                                if (!norm.contains('T')) norm = norm.replaceFirst(' ', 'T');
                                if (!norm.endsWith('Z') && !norm.contains('+')) norm += 'Z';
                                final dt = DateTime.parse(norm).toLocal();
                                formattedDate = DateFormat('MMM dd, yyyy - hh:mm a').format(dt);
                              } catch (_) {}
                            }

                            return Card(
                              margin: const EdgeInsets.only(bottom: 16),
                              elevation: 2,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Header: Product Title & Delete Button
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                productName,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16,
                                                  color: Colors.blue,
                                                ),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                'ID: ${rev['productId'] ?? ''}',
                                                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                                              ),
                                            ],
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                                          tooltip: 'Delete Review',
                                          onPressed: () => _confirmDeleteReview(rev),
                                        ),
                                      ],
                                    ),
                                    const Divider(height: 16),

                                    // Reviewer Info & Rating
                                    Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 18,
                                          backgroundColor: Colors.blue[100],
                                          child: Text(
                                            userName.substring(0, 1).toUpperCase(),
                                            style: TextStyle(color: Colors.blue[900], fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                userName,
                                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                              ),
                                              if (userEmail.isNotEmpty)
                                                Text(
                                                  userEmail,
                                                  style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                                                ),
                                            ],
                                          ),
                                        ),
                                        Row(
                                          children: List.generate(5, (starIdx) {
                                            return Icon(
                                              starIdx < rating ? Icons.star : Icons.star_border,
                                              color: Colors.amber,
                                              size: 16,
                                            );
                                          }),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),

                                    // Comment
                                    if (comment.isNotEmpty)
                                      Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: Colors.grey[100],
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Text(
                                          comment,
                                          style: const TextStyle(fontSize: 14, color: Colors.black87),
                                        ),
                                      ),

                                    // Review Image Thumbnail
                                    if (imgUrl != null) ...[
                                      const SizedBox(height: 12),
                                      GestureDetector(
                                        onTap: () => _showImageDialog(imgUrl),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(10),
                                          child: CachedNetworkImage(
                                            imageUrl: imgUrl,
                                            width: 110,
                                            height: 110,
                                            fit: BoxFit.cover,
                                            placeholder: (context, url) => Container(
                                              width: 110,
                                              height: 110,
                                              color: Colors.grey[200],
                                              child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                                            ),
                                            errorWidget: (context, url, error) => Container(
                                              width: 110,
                                              height: 110,
                                              color: Colors.grey[200],
                                              child: const Icon(Icons.broken_image, color: Colors.grey),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],

                                    const SizedBox(height: 8),
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: Text(
                                        formattedDate,
                                        style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
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
