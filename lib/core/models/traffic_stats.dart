class TrafficStats {
  final double downloadSpeedKbps;
  final double uploadSpeedKbps;
  final double totalDownloadMb;
  final double totalUploadMb;
  final int activeConnections;
  final List<double> recentDownloadHistory;
  final List<double> recentUploadHistory;

  TrafficStats({
    this.downloadSpeedKbps = 0.0,
    this.uploadSpeedKbps = 0.0,
    this.totalDownloadMb = 0.0,
    this.totalUploadMb = 0.0,
    this.activeConnections = 0,
    this.recentDownloadHistory = const [],
    this.recentUploadHistory = const [],
  });
}
