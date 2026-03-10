# Halide - Database Schema

*Source of Truth for the PostgreSQL Database configuration.*

## Users
Stores application user profiles. **Firebase Auth** is the source of truth for authentication, passwords, and sessions. This table links Firebase identities to our relational data.

| Field | Type | Modifiers | Description |
| :--- | :--- | :--- | :--- |
| `id` | VARCHAR(255) | PRIMARY KEY | **Firebase UID** (matches `user.uid` from Firebase) |
| `email` | VARCHAR(255) | UNIQUE, NOT NULL | Synced from Firebase |
| `display_name` | VARCHAR(255) | | Synced from Firebase |
| `avatar_url` | TEXT | | Synced from Firebase `photoURL` |
| `created_at` | TIMESTAMP | DEFAULT NOW() | Record creation time |

## Film Master Data (FilmStocks)
Catalog of available film types.

| Field | Type | Modifiers | Description |
| :--- | :--- | :--- | :--- |
| `id` | UUID | PRIMARY KEY, DEFAULT gen_random_uuid() | Unique identifier |
| `brand` | VARCHAR(100) | NOT NULL | e.g. Kodak, Fujifilm, Ilford |
| `name` | VARCHAR(100) | NOT NULL | Model, e.g. Portra, Superia, HP5 |
| `iso` | INTEGER | NOT NULL | Box ISO speed |
| `format` | ENUM | NOT NULL | '135/35mm', '120/Medium Format', 'Large Format', etc. |
| `color_type` | ENUM | NOT NULL | 'Color Negative', 'B&W', 'Slide' |
| `description` | TEXT | | A short description about the film stock |
| `best_practice` | TEXT | | Tips on how to use/meter this stock |
| `image_urls` | JSONB | | Array of strings containing photo URLs |

## Camera Master Data (Cameras)
Catalog of available cameras used by users.

| Field | Type | Modifiers | Description |
| :--- | :--- | :--- | :--- |
| `id` | UUID | PRIMARY KEY, DEFAULT gen_random_uuid() | Unique identifier |
| `brand` | VARCHAR(100) | NOT NULL | e.g. Leica, Canon, Nikon |
| `model` | VARCHAR(100) | NOT NULL | e.g. M6, AE-1 |
| `camera_type` | ENUM | NOT NULL | 'SLR', 'TLR', 'Rangefinder', 'Point & Shoot', 'View Camera' |
| `description` | TEXT | | A short description about the camera |
| `best_practice` | TEXT | | Tips on common quirks, loading issues, etc. |
| `image_urls` | JSONB | | Array of strings containing photo URLs |

## User Equipment (UserCameras)
A specific camera owned and evaluated by a User.

| Field | Type | Modifiers | Description |
| :--- | :--- | :--- | :--- |
| `id` | UUID | PRIMARY KEY, DEFAULT gen_random_uuid() | Unique identifier |
| `user_id` | VARCHAR(255) | FOREIGN KEY (Users.id) | The owner of the camera |
| `camera_id` | UUID | FOREIGN KEY (Cameras.id) | Link to Camera Master |
| `rating_functional` | INTEGER | CHECK (rating_functional BETWEEN 1 AND 10) | Condition of mechanicals (1-10) |
| `rating_view` | INTEGER | CHECK (rating_view BETWEEN 1 AND 10) | Condition of viewfinder/glass (1-10) |
| `rating_looking` | INTEGER | CHECK (rating_looking BETWEEN 1 AND 10) | Cosmetic condition (1-10) |
| `created_at` | TIMESTAMP | DEFAULT NOW() | When added to collection |

## Rolls
A specific roll of film shot by a User.

| Field | Type | Modifiers | Description |
| :--- | :--- | :--- | :--- |
| `id` | UUID | PRIMARY KEY, DEFAULT gen_random_uuid() | Unique identifier |
| `user_id` | VARCHAR(255) | FOREIGN KEY (Users.id) | Owner of the roll |
| `film_stock_id` | UUID | FOREIGN KEY (FilmStocks.id) | The film used |
| `user_camera_id` | UUID | FOREIGN KEY (UserCameras.id) | The specific camera used |
| `shot_at_iso` | INTEGER | | ISO the user actually shot it at |
| `expired_year` | INTEGER | | e.g. 2015, 2026. Null if fresh |
| `status` | ENUM | DEFAULT 'Shooting' | 'Shooting', 'Finished Shooting', 'At Lab', 'Result Received' |
| `created_at` | TIMESTAMP | DEFAULT NOW() | When the roll was started |

## Images
Individual exposures scanned from a Roll.

| Field | Type | Modifiers | Description |
| :--- | :--- | :--- | :--- |
| `id` | UUID | PRIMARY KEY, DEFAULT gen_random_uuid() | Unique identifier |
| `roll_id` | UUID | FOREIGN KEY (Rolls.id) | Parent roll |
| `frame_number` | INTEGER | | Frame 1-36 |
| `image_url` | VARCHAR | NOT NULL | Cloud storage URL |
| `aperture` | DECIMAL(3,1) | | Lens aperture used |
| `shutter_speed`| VARCHAR(20) | | e.g. "1/250" |
| `notes` | TEXT | | Optional context |
