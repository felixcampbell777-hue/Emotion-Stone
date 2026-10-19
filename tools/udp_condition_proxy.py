"""Disposable per-client UDP forwarder for controlled ENet network conditions."""
import heapq
import random
import select
import socket
import threading
import time


class UDPConditionProxy:
    def __init__(self, target_port, rtt_ms=150, jitter_ms=15, loss=.02, seed=18481, listen_port=0):
        self.target = ('127.0.0.1', target_port)
        self.sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        self.sock.bind(('127.0.0.1', listen_port))
        self.port = self.sock.getsockname()[1]
        self.delay = rtt_ms / 2000
        self.jitter = jitter_ms / 1000
        self.loss = loss
        self.random = random.Random(seed)
        self.stop = threading.Event()
        self.stats = {'packets': 0, 'bytes': 0, 'dropped': 0, 'peak_queue': 0}
        self.thread = threading.Thread(target=self.run, daemon=True)
        self.thread.start()

    def run(self):
        client = None
        queue = []
        sequence = 0
        while not self.stop.is_set():
            readable, _, _ = select.select([self.sock], [], [], .003)
            if readable:
                payload, sender = self.sock.recvfrom(65535)
                destination = client if sender == self.target else self.target
                if sender != self.target:
                    client = sender
                if destination:
                    self.stats['packets'] += 1
                    self.stats['bytes'] += len(payload)
                    if self.random.random() < self.loss:
                        self.stats['dropped'] += 1
                    else:
                        sequence += 1
                        due = time.monotonic() + max(0, self.delay + self.random.uniform(-self.jitter, self.jitter))
                        heapq.heappush(queue, (due, sequence, payload, destination))
                        self.stats['peak_queue'] = max(self.stats['peak_queue'], len(queue))
            now = time.monotonic()
            while queue and queue[0][0] <= now:
                _, _, payload, destination = heapq.heappop(queue)
                self.sock.sendto(payload, destination)

    def close(self):
        self.stop.set()
        self.thread.join(timeout=1)
        self.sock.close()
