import 'package:flutter/material.dart';

class FirstAidScreen extends StatelessWidget {
  const FirstAidScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final items = [
      _FirstAidItem(
        title: 'CPR',
        description:
            'Step-by-step guide for performing CPR safely until help arrives.',
        icon: Icons.favorite,
        detailScreen: const _FirstAidDetailScreen(
          title: 'CPR',
          bulletPoints: [
            'Call for emergency services immediately.',
            'If the person is unresponsive and not breathing normally, begin chest compressions.',
            'Place the heel of one hand in the center of the chest, then place your other hand on top and interlock your fingers.',
            'Keep your arms straight and shoulders directly above your hands.',
            'Push hard and fast at a rate of about 100–120 compressions per minute.',
            'Allow the chest to fully recoil between compressions.',
            'If trained, give rescue breaths after every 30 compressions (tilt head, lift chin, pinch nose, give 2 gentle breaths).',
            'Continue CPR until professional help takes over or the person starts breathing normally.',
          ],
        ),
      ),
      _FirstAidItem(
        title: 'Bleeding',
        description:
            'How to control bleeding and protect against shock or infection.',
        icon: Icons.healing,
        detailScreen: const _FirstAidDetailScreen(
          title: 'Bleeding',
          bulletPoints: [
            'Stay calm and reassure the injured person.',
            'Wear disposable gloves if available to protect yourself from blood.',
            'Apply firm, direct pressure to the wound with a clean cloth or bandage.',
            'If blood soaks through, do not remove the original cloth—add more layers on top.',
            'Raise the injured limb above heart level if possible and not broken.',
            'Do not remove large or deeply embedded objects; instead, apply pressure around them.',
            'Call emergency services if bleeding is severe or does not stop after 10 minutes of steady pressure.',
            'Keep the person warm and lying down to help prevent shock.',
          ],
        ),
      ),
      _FirstAidItem(
        title: 'Broken Bone',
        description:
            'Recognize fractures and keep the injured area stable and safe.',
        icon: Icons.accessibility_new,
        detailScreen: const _FirstAidDetailScreen(
          title: 'Broken bone',
          bulletPoints: [
            'Call emergency services if the injury is severe or the person cannot move safely.',
            'Do not try to straighten a clearly deformed limb.',
            'Immobilize the injured area using a splint or sling if trained to do so.',
            'Support the joint above and below the suspected fracture.',
            'Apply an ice pack wrapped in cloth to reduce swelling and pain (do not place ice directly on skin).',
            'Check for circulation beyond the injury: color, warmth, and feeling in fingers or toes.',
            'Do not allow the person to eat or drink in case surgery is needed.',
            'Monitor breathing and consciousness while waiting for medical help.',
          ],
        ),
      ),
      _FirstAidItem(
        title: 'Choking',
        description:
            'How to respond when someone is choking and cannot breathe.',
        icon: Icons.warning_amber_rounded,
        detailScreen: const _FirstAidDetailScreen(
          title: 'Choking',
          bulletPoints: [
            'Ask the person if they are choking and if they can speak or cough.',
            'If they cannot speak, cough, or breathe, act immediately.',
            'Stand behind the person and wrap your arms around their waist.',
            'Make a fist with one hand and place it just above the belly button.',
            'Grasp your fist with your other hand and give quick, inward and upward thrusts (the Heimlich maneuver).',
            'Repeat thrusts until the object is expelled or the person becomes unresponsive.',
            'If the person becomes unresponsive, gently lower them to the ground and begin CPR.',
            'For a choking infant, use back blows and chest thrusts instead of abdominal thrusts.',
          ],
        ),
      ),
    ];

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'First Aid Tips',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: ListView.separated(
          itemCount: items.length,
          separatorBuilder: (_, _) => const SizedBox(height: 16),
          itemBuilder: (context, index) {
            final item = items[index];
            return _FirstAidCard(item: item);
          },
        ),
      ),
    );
  }
}

class _FirstAidItem {
  final String title;
  final String description;
  final IconData icon;
  final Widget detailScreen;

  const _FirstAidItem({
    required this.title,
    required this.description,
    required this.icon,
    required this.detailScreen,
  });
}

class _FirstAidCard extends StatelessWidget {
  final _FirstAidItem item;

  const _FirstAidCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => item.detailScreen,
            ),
          );
        },
        child: Container(
          decoration: BoxDecoration(
            color: Colors.grey[900],
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.grey[800],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  item.icon,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      item.description,
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.arrow_forward_ios,
                color: Colors.white70,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FirstAidDetailScreen extends StatelessWidget {
  final String title;
  final List<String> bulletPoints;

  const _FirstAidDetailScreen({
    required this.title,
    required this.bulletPoints,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: false,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[900],
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'What to do in this situation',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                ...bulletPoints.map(
                  (point) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '• ',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            point,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

