# Kara Bloome API

Rails API application with authentication, authorization, and background job processing.

## Getting Started

### Prerequisites

- Ruby (check `.ruby-version` or `Gemfile` for version)
- PostgreSQL
- Redis (for background job processing)
- Bundler

### Setup

1. Install dependencies:

   ```bash
   bundle install
   ```

2. Set up the database:

   ```bash
   rails db:create
   ```

3. Enable PostGIS extension (required for warehouse location features):

   ```bash
   rails db
   CREATE EXTENSION IF NOT EXISTS postgis;
   \q
   ```

4. Run migrations and seed:

   ```bash
   rails db:migrate
   rails db:seed
   ```

5. Install and start Redis:

   On macOS with Homebrew:

   ```bash
   brew install redis
   brew services start redis
   ```

   On Linux:

   ```bash
   sudo apt-get install redis-server
   sudo systemctl start redis
   ```

   Or use Docker:

   ```bash
   docker run -d -p 6379:6379 redis:latest
   ```

6. Configure environment variables (if needed):
   - `MAILER_FROM`: Email address for mailer (defaults to `noreply@localhost`)
   - `REDIS_URL`: Redis connection URL (defaults to `redis://localhost:6379/1` - uses database 1 to avoid conflicts with other projects)
   - `PAYSTACK_SECRET_KEY`: Secret key for Paystack payment and transfer API calls
   - `PAYSTACK_GH_MTN_MOMO_CODE`: Paystack transfer recipient bank code for MTN Ghana MoMo
   - `PAYSTACK_GH_VODAFONE_MOMO_CODE`: Paystack transfer recipient bank code for Telecel/Vodafone Cash
   - `PAYSTACK_GH_AIRTELTIGO_MOMO_CODE`: Paystack transfer recipient bank code for AT Money
   - `SIDEKIQ_USERNAME`: Username for Sidekiq web UI in production (defaults to `admin`)
   - `SIDEKIQ_PASSWORD`: Password for Sidekiq web UI in production (defaults to `change-me` - **change this!**)

### Starting the Application

To run the full application, you need to start two processes:

1. **Start the Rails server** (in one terminal):

   ```bash
   bin/dev
   ```

   Or:

   ```bash
   rails server
   ```

   The API will be available at `http://localhost:3000`

2. **Start the background job processor** (in another terminal):
   ```bash
   bin/jobs
   ```
   This processes background jobs like welcome emails and OTP emails.

### Running Tests

```bash
rails test
```

### Background Jobs

The application uses **Sidekiq** with **Redis** for background job processing. This provides:

- Fast, efficient job processing
- Better scalability than database-backed queues
- Built-in web UI for monitoring jobs

Jobs are automatically enqueued for:

- Welcome emails (sent after user registration)
- OTP emails (sent during login and OTP enablement)

**Important:** Make sure Redis is running and `bin/jobs` is started to process these background jobs.

#### Sidekiq Web UI

You can monitor jobs by visiting `http://localhost:3000/sidekiq` after starting the Rails server. This provides a web interface to view:

- Job status and queues
- Job history and statistics
- Failed jobs and retries
- Real-time job processing

**Access:**

- **Development**: Open access (no authentication required)
- **Production**: Protected with HTTP Basic Auth (set `SIDEKIQ_USERNAME` and `SIDEKIQ_PASSWORD` environment variables)

**Important for Production:** Make sure to set strong `SIDEKIQ_USERNAME` and `SIDEKIQ_PASSWORD` environment variables before deploying to production!

###Deployed to Production Server
Deyarrah Services;
Deyarrah API Application
$ sudo systemctl status deyarrah
- Deyarrah Sidekiq Service
$ sudo systemctl status deyarrah-sidekiq
*when updates are made restart the services with;
sudo systemctl restart deyarrah
sudo systemctl restart deyarrah-sidekiq
