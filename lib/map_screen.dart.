
import 'package:flutter/material.dart';
import 'package:yandex_maps_mapkit/yandex_map.dart';

class CockpitMapScreen extends StatelessWidget {
  const CockpitMapScreen({
    super.key,
    required this.mapkitAvailable,
  });

  final bool mapkitAvailable;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080A0F),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
              child: Row(
                children: [
                  const Icon(
                    Icons.map_outlined,
                    color: Color(0xFF8B7CFF),
                    size: 25,
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'НАВИГАЦИЯ',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.5,
                          ),
                        ),
                        Text(
                          'НЕ ШТАТ AUTO COCKPIT',
                          style: TextStyle(
                            color: Colors.white54,
                            fontSize: 9,
                            letterSpacing: 2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(
                      Icons.close,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: mapkitAvailable
                    ? const YandexMap()
                    : const _MapUnavailable(),
              ),
            ),
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                'Карта предоставляется Яндексом',
                style: TextStyle(
                  color: Colors.white38,
                  fontSize: 10,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MapUnavailable extends StatelessWidget {
  const _MapUnavailable();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: const Color(0xFF171C26),
      padding: const EdgeInsets.all(24),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.map_outlined,
            color: Color(0xFF8B7CFF),
            size: 64,
          ),
          SizedBox(height: 18),
          Text(
            'Карта пока недоступна',
            style: TextStyle(
              color: Colors.white,
              fontSize: 19,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 10),
          Text(
            'Проверь API-ключ MapKit и его передачу при сборке приложения.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white54,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
