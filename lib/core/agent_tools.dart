import 'package:google_generative_ai/google_generative_ai.dart';

class VyomaAgentTools {
  static final Tool omniscientToolSet = Tool(
    functionDeclarations: [
      FunctionDeclaration(
        'get_chronos_state',
        'Pulls exact time, gap since last login, and current temporal status (Active vs MIA). Call this first if you are unsure of the time mathematically.',
        Schema(SchemaType.object, properties: {}),
      ),
      FunctionDeclaration(
        'update_timetable',
        'Natively guarantees 24-hr layout creation for daily schedules. Use this to schedule tasks into the timetable.',
        Schema(SchemaType.object, properties: {
          'slots': Schema(SchemaType.array, items: Schema(SchemaType.object, properties: {
            'dayOfWeek': Schema(SchemaType.string, description: 'e.g. Monday'),
            'startTime': Schema(SchemaType.string, description: '24-hour format HH:mm'),
            'endTime': Schema(SchemaType.string, description: '24-hour format HH:mm'),
            'subject': Schema(SchemaType.string),
            'venue': Schema(SchemaType.string),
          })),
        }),
      ),
      FunctionDeclaration(
        'get_google_calendar_events',
        'Pulls upcoming meetings natively directly from the synced Google accounts.',
        Schema(SchemaType.object, properties: {}),
      ),
      FunctionDeclaration(
        'manage_deferred_tasks',
        'Read, create, or mark internal tasks as complete without manual UI interaction.',
        Schema(SchemaType.object, properties: {
          'action': Schema(SchemaType.string, description: 'read, create, complete'),
          'taskId': Schema(SchemaType.string, nullable: true),
          'taskTitle': Schema(SchemaType.string, nullable: true),
        }),
      ),
      FunctionDeclaration(
        'query_preference',
        'Dynamically pulls the user long-term habits/preferences from the Vector DB (Supermemory).',
        Schema(SchemaType.object, properties: {
          'topic': Schema(SchemaType.string),
        }),
      ),
      FunctionDeclaration(
        'save_preference',
        'The AI autonomously decides to memorize a preference you mention into Supermemory.',
        Schema(SchemaType.object, properties: {
          'key': Schema(SchemaType.string),
          'value': Schema(SchemaType.string),
        }),
      ),
      FunctionDeclaration(
        'get_device_telemetry',
        'Inspects current focused window, battery, and location info.',
        Schema(SchemaType.object, properties: {}),
      ),
      FunctionDeclaration(
        'get_metrics',
        'Analyzes focus vs. distraction scores.',
        Schema(SchemaType.object, properties: {}),
      ),
      FunctionDeclaration(
        'get_friend_activity',
        'Fetches recent public activities of peers for social nudging.',
        Schema(SchemaType.object, properties: {}),
      ),
    ],
  );
}
