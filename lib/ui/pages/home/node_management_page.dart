import 'package:flutter/material.dart';
import 'package:fungi_app/app/controllers/fungi_controller.dart';
import 'package:fungi_app/src/grpc/generated/fungi_daemon.pb.dart';
import 'package:fungi_app/ui/widgets/enhanced_card.dart';
import 'package:fungi_app/ui/widgets/text.dart';
import 'package:get/get.dart';

class NodeManagementPage extends StatefulWidget {
  const NodeManagementPage({super.key});

  @override
  State<NodeManagementPage> createState() => _NodeManagementPageState();
}

class _NodeManagementPageState extends State<NodeManagementPage>
    with AutomaticKeepAliveClientMixin {
  final controller = Get.find<FungiController>();
  final _scrollController = ScrollController();
  final _expandedPeerIds = <String>{};

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Obx(() {
      final peers = controller.addressBook;
      return RefreshIndicator(
        onRefresh: controller.refreshNodeManagementData,
        child: ListView(
          controller: _scrollController,
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Peers',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Known peers from the address book, plus connection state and published catalog services.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      if (controller.nodeManagementLoading.value)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            'Refreshing peers… cards will update as each peer finishes.',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: controller.nodeManagementLoading.value
                      ? null
                      : controller.refreshNodeManagementData,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (peers.isEmpty)
              Text(
                'No known peers yet.',
                style: Theme.of(context).textTheme.bodyMedium,
              )
            else
              ...peers.map(
                (peer) => _PeerCard(
                  key: ValueKey(peer.peerId),
                  peer: peer,
                  expanded: _expandedPeerIds.contains(peer.peerId),
                  onExpansionChanged: (expanded) {
                    setState(() {
                      if (expanded) {
                        _expandedPeerIds.add(peer.peerId);
                      } else {
                        _expandedPeerIds.remove(peer.peerId);
                      }
                    });
                  },
                ),
              ),
          ],
        ),
      );
    });
  }
}

class _PeerCard extends GetView<FungiController> {
  const _PeerCard({
    super.key,
    required this.peer,
    required this.expanded,
    required this.onExpansionChanged,
  });

  final PeerInfo peer;
  final bool expanded;
  final ValueChanged<bool> onExpansionChanged;

  @override
  Widget build(BuildContext context) {
    final connections = controller.connectionsForPeer(peer.peerId);
    final catalogServices = controller.servicesForPeer(peer.peerId);
    final latency = controller.bestLatencyForPeer(peer.peerId);
    final refreshState = controller.peerRefreshStateFor(peer.peerId);
    final title = peer.alias.isNotEmpty
        ? peer.alias
        : (peer.hostname.isNotEmpty ? peer.hostname : peer.peerId);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: EnhancedCard(
        child: ExpansionTile(
          key: PageStorageKey('peer-${peer.peerId}'),
          initiallyExpanded: expanded,
          onExpansionChanged: onExpansionChanged,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (refreshState.isLoading)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              IconButton(
                tooltip: 'Refresh peer',
                onPressed: refreshState.isLoading
                    ? null
                    : () => controller.refreshSinglePeerServices(peer.peerId),
                icon: const Icon(Icons.refresh, size: 20),
              ),
              Icon(expanded ? Icons.expand_less : Icons.expand_more),
            ],
          ),
          title: Text(title),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              TruncatedId(id: peer.peerId),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  Chip(
                    label: Text(connections.isEmpty ? 'offline' : 'connected'),
                  ),
                  Chip(label: Text('${connections.length} connections')),
                  Chip(label: Text('${catalogServices.length} services')),
                  if (latency != null) Chip(label: Text('$latency ms')),
                ],
              ),
              const SizedBox(height: 6),
              _PeerRefreshStatus(peerId: peer.peerId),
            ],
          ),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (peer.hostname.isNotEmpty) Chip(label: Text(peer.hostname)),
                if (peer.os.isNotEmpty) Chip(label: Text(peer.os)),
                if (peer.version.isNotEmpty)
                  Chip(label: Text('v${peer.version}')),
                if (peer.publicIp.isNotEmpty) Chip(label: Text(peer.publicIp)),
              ],
            ),
            if (connections.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Connections',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              ...connections.map(
                (connection) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            Chip(label: Text(connection.direction)),
                            Chip(
                              label: Text(
                                connection.isRelay ? 'relay' : 'direct',
                              ),
                            ),
                            if (connection.hasLastRttMs())
                              Chip(label: Text('${connection.lastRttMs} ms')),
                            if (connection.activeStreamsTotal > 0)
                              Chip(
                                label: Text(
                                  '${connection.activeStreamsTotal} streams',
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          connection.remoteAddr,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            Text(
              'Published Services',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            if (refreshState.isLoading && catalogServices.isEmpty)
              Text(
                'Refreshing published services…',
                style: Theme.of(context).textTheme.bodySmall,
              )
            else if (refreshState.hasError && catalogServices.isEmpty)
              Text(
                refreshState.error,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              )
            else if (catalogServices.isEmpty)
              Text(
                'No published services found.',
                style: Theme.of(context).textTheme.bodySmall,
              )
            else
              ...catalogServices.map(
                (service) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              service.displayName,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${service.usageKind ?? service.transportKind} · ${service.runtime} · ${service.publishedEndpoints.length} endpoints',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      if (service.running) Chip(label: const Text('running')),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PeerRefreshStatus extends GetView<FungiController> {
  const _PeerRefreshStatus({required this.peerId});

  final String peerId;

  @override
  Widget build(BuildContext context) {
    final state = controller.peerRefreshStateFor(peerId);
    final theme = Theme.of(context);

    if (state.hasError) {
      return Text(
        'Last refresh failed: ${state.error}',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.error,
        ),
      );
    }

    if (state.isLoading) {
      return Text(
        'Refreshing…',
        style: theme.textTheme.bodySmall,
      );
    }

    if (state.updatedAt != null) {
      return Text(
        'Updated ${_formatRelativeTime(state.updatedAt!)}',
        style: theme.textTheme.bodySmall,
      );
    }

    return Text(
      'Not refreshed yet.',
      style: theme.textTheme.bodySmall,
    );
  }

  String _formatRelativeTime(DateTime updatedAt) {
    final diff = DateTime.now().difference(updatedAt);
    if (diff.inSeconds < 30) {
      return 'just now';
    }
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    }
    if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    }
    return '${diff.inDays}d ago';
  }
}
