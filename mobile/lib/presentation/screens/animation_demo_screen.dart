import 'package:flutter/material.dart';
import '../animations/rive_animation_widget.dart';
import '../animations/lottie_animation_widget.dart';
import '../animations/liquid_swipe_widget.dart';
import '../animations/crystalize_chart_widget.dart';

class AnimationDemoScreen extends StatelessWidget {
  const AnimationDemoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Sample data for charts
    final sampleData = [
      {'month': 'Jan', 'value': 20},
      {'month': 'Feb', 'value': 35},
      {'month': 'Mar', 'value': 30},
      {'month': 'Apr', 'value': 45},
      {'month': 'May', 'value': 40},
    ];

    // Pages for liquid swipe
    final liquidPages = [
      LiquidSwipePage(
        title: 'Welcome',
        description: 'Experience amazing animations in our app',
        backgroundColor: Colors.blue.shade600,
        icon: Icons.animation,
      ),
      LiquidSwipePage(
        title: 'Rive Animations',
        description: 'Smooth vector animations powered by Rive',
        backgroundColor: Colors.green.shade600,
        icon: Icons.animation_outlined,
      ),
      LiquidSwipePage(
        title: 'Lottie Animations',
        description: 'Beautiful vector animations with Lottie',
        backgroundColor: Colors.orange.shade600,
        icon: Icons.movie_creation,
      ),
      LiquidSwipePage(
        title: 'Data Visualization',
        description: 'Crystal clear data visualization',
        backgroundColor: Colors.purple.shade600,
        icon: Icons.bar_chart,
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Animation Demo'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Title
              const Text(
                'Animation Showcase',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),

              // Rive Animation Section
              Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      const Text(
                        'Rive Animations',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      // Using a placeholder since we don't have actual Rive files
                      Container(
                        height: 200,
                        decoration: BoxDecoration(
                          color: Colors.blue.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.animation,
                            size: 64,
                            color: Colors.blue,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      ElevatedButton(
                        onPressed: () {
                          // In a real implementation, this would trigger a Rive animation
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Rive animation triggered!'),
                            ),
                          );
                        },
                        child: const Text('Play Rive Animation'),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Lottie Animation Section
              Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      const Text(
                        'Lottie Animations',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      // Using a placeholder since we don't have actual Lottie files
                      Container(
                        height: 200,
                        decoration: BoxDecoration(
                          color: Colors.green.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.movie_creation,
                            size: 64,
                            color: Colors.green,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      ElevatedButton(
                        onPressed: () {
                          // In a real implementation, this would play a Lottie animation
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Lottie animation played!'),
                            ),
                          );
                        },
                        child: const Text('Play Lottie Animation'),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Liquid Swipe Section
              Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      const Text(
                        'Liquid Swipe Effects',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 300,
                        child: LiquidSwipeWidget(
                          pages: liquidPages,
                          fullSlide: true,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Crystalize Data Visualization Section
              Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      const Text(
                        'Data Visualization',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      CrystalizeChartWidget(
                        data: sampleData,
                        xField: 'month',
                        yField: 'value',
                        chartType: 'bar',
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
