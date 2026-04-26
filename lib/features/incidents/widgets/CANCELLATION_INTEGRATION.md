# Cancellation Request Widget Integration Guide

## Overview

The `CancellationRequestWidget` displays real-time cancellation request status for incidents. It automatically updates when cancellation events are received via WebSocket.

## Features

- **Task 3.1**: Shows pending cancellation requests with reason
- **Task 3.2**: Shows approved cancellation status
- **Task 3.3**: Shows rejected cancellation status with reason

## Usage

### 1. Import the widget

```dart
import 'package:merchanic_repair/features/incidents/widgets/cancellation_request_widget.dart';
```

### 2. Add to incident details screen

Add the widget to your incident details screen (e.g., `incident_detail_screen.dart`):

```dart
@override
Widget build(BuildContext context, WidgetRef ref) {
  return Scaffold(
    appBar: AppBar(title: Text('Incidente #${widget.incidentId}')),
    body: SingleChildScrollView(
      child: Column(
        children: [
          // ... other incident details widgets ...
          
          // Add cancellation request widget
          CancellationRequestWidget(incidentId: widget.incidentId),
          
          // ... more widgets ...
        ],
      ),
    ),
  );
}
```

### 3. Widget behavior

The widget automatically:
- Hides when there's no cancellation request
- Shows pending requests with orange color
- Shows approved requests with green color
- Shows rejected requests with red color
- Updates in real-time when events are received

## Event Flow

1. **cancellation.requested** → Widget shows pending status with reason
2. **cancellation.approved** → Widget updates to approved status (green)
3. **cancellation.rejected** → Widget updates to rejected status with reason (red)

## Service Initialization

The `CancellationRealtimeService` is automatically initialized when an administrator logs in (see `auth_provider.dart`). No manual initialization is required.

## State Management

The widget uses Riverpod to watch the `cancellationRealtimeProvider` state. The state is automatically updated by the `CancellationRealtimeService` when WebSocket events are received.

## Notifications

When cancellation events are received, the service also shows local notifications:
- "Solicitud de Cancelación #X" for requested events
- "Cancelación Aprobada #X" for approved events
- "Cancelación Rechazada #X" for rejected events

## Example Screens

### Pending Request
```
┌─────────────────────────────────────┐
│ ⏱️ Solicitud de Cancelación Pendiente│
│                                     │
│ Razón de la solicitud:              │
│ Cliente no puede esperar más        │
│                                     │
│ Solicitado: 15/01/2024 14:30       │
└─────────────────────────────────────┘
```

### Approved Request
```
┌─────────────────────────────────────┐
│ ✅ Cancelación Aprobada              │
│                                     │
│ La solicitud de cancelación ha sido │
│ aprobada.                           │
│                                     │
│ Aprobado: 15/01/2024 14:35         │
└─────────────────────────────────────┘
```

### Rejected Request
```
┌─────────────────────────────────────┐
│ ❌ Cancelación Rechazada             │
│                                     │
│ Razón del rechazo:                  │
│ Técnico ya está en camino           │
│                                     │
│ Rechazado: 15/01/2024 14:35        │
└─────────────────────────────────────┘
```

## Testing

To test the widget:

1. Login as administrator
2. Create an incident
3. Request cancellation via backend API
4. Observe the widget appear with pending status
5. Approve/reject the cancellation via backend API
6. Observe the widget update in real-time

## Backend Events

The widget responds to these WebSocket events:

```json
// cancellation.requested
{
  "event_type": "cancellation.requested",
  "payload": {
    "incident_id": 123,
    "requested_by": 456,
    "reason": "Cliente no puede esperar",
    "requested_at": "2024-01-15T14:30:00Z"
  }
}

// cancellation.approved
{
  "event_type": "cancellation.approved",
  "payload": {
    "incident_id": 123,
    "approved_by": 789,
    "approved_at": "2024-01-15T14:35:00Z"
  }
}

// cancellation.rejected
{
  "event_type": "cancellation.rejected",
  "payload": {
    "incident_id": 123,
    "rejected_by": 789,
    "reason": "Técnico ya está en camino",
    "rejected_at": "2024-01-15T14:35:00Z"
  }
}
```
