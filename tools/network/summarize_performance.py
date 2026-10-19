"""Summarize bounded real-server evidence without treating startup as active play."""
import argparse
import json
from pathlib import Path


def summarize(report, expected_players=8):
    samples = report.get('server_samples', [])
    # A continuous 600-tick window is required: slow ticks take more wall time,
    # and a population interruption invalidates earlier warm-up.
    steady = []
    population_start_tick = None
    for sample in samples:
        health = sample.get('health', {})
        elapsed = sample.get('wall_elapsed_seconds', sample.get('seconds', 0))
        if elapsed > report.get('requested_client_seconds', float('inf')):
            continue
        if health.get('active_players', health.get('players')) != expected_players or not health.get('ready'):
            population_start_tick = None
            continue
        tick = health.get('tick', 0)
        if population_start_tick is None:
            population_start_tick = tick
        if tick - population_start_tick >= 600:
            steady.append(sample)
    health = steady[-1]['health'] if steady else report.get('server_health', {})
    performance = health.get('performance', {})
    snapshot = performance.get('snapshots', {})
    peers = snapshot.get('per_peer', {})
    result = {'scope': 'Latest rolling 600-tick active window' if steady else 'Final server health only; active window not established',
              'expected_players': expected_players, 'steady_sample_count': len(steady),
              'functional_passed': report.get('passed', False),
              'physics_ms_p95': performance.get('physics_ms_p95'),
              'interval_ms_p95': performance.get('interval_ms_p95'),
              'active_window_physics_ms_max': performance.get('physics_ms_window_max') if steady else None,
              'active_window_interval_ms_max': performance.get('interval_ms_window_max') if steady else None,
              'lifetime_physics_ms_max_includes_startup': performance.get('physics_ms_max'),
              'stages': performance.get('stages', {}),
              'snapshot_mean_compress_ms': snapshot.get('compress_usec', 0) / max(1, snapshot.get('packets', 0)) / 1000,
              'snapshot_compressed_bytes_per_peer': peers,
              'server_peak_rss_mib_includes_startup': (report.get('server_peak_rss_kib') or 0) / 1024,
              'server_peak_cpu_percent': report.get('server_peak_cpu_percent')}
    if steady:
        result['active_window_physics_p95_max_ms'] = max(sample['health'].get('performance', {}).get('physics_ms_p95', 0) for sample in steady)
        result['active_window_physics_ms_max'] = max((sample['health'].get('performance', {}).get('physics_ms_window_max') or 0) for sample in steady) or None
        result['active_window_interval_ms_max'] = max((sample['health'].get('performance', {}).get('interval_ms_window_max') or 0) for sample in steady) or None
        result['active_peak_rss_mib'] = max((sample.get('rss_kib') or 0) for sample in steady) / 1024
        result['active_peak_cpu_percent'] = max((sample.get('cpu_percent') or 0) for sample in steady)
        first = steady[0]['health']
        duration = health.get('unix', 0) - first.get('unix', 0)
        if duration > 0:
            first_peers = first.get('performance', {}).get('snapshots', {}).get('per_peer', {})
            result['active_peer_kilobits_per_second'] = {
                peer: (count - first_peers.get(peer, count)) * 8 / duration / 1000
                for peer, count in peers.items()}
    result['physics_callback_60hz_budget_passed'] = bool(steady and report.get('passed') and all(
        sample['health'].get('performance', {}).get('physics_ms_p95', float('inf')) <= 1000 / 60 for sample in steady))
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('report', type=Path)
    parser.add_argument('--expected-players', type=int, default=8)
    args = parser.parse_args()
    print(json.dumps(summarize(json.loads(args.report.read_text()), args.expected_players), indent=2))


if __name__ == '__main__':
    main()
