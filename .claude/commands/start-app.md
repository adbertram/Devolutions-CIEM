---
description: Start the Devolutions CIEM development environment
model: claude-haiku-4-5-20251001
argument-hint: [up|stop|restart|status|logs]
---

Execute the start.sh script to manage the Devolutions CIEM development environment.

If an argument is provided ($1), pass it to the script: `./start.sh $1`
Otherwise, run with default (up): `./start.sh`

The script manages:
- Backend services in Docker (API, Postgres, Valkey, Neo4j, Celery workers, MCP server)
- UI running locally via pnpm for hot-reload

Available commands:
- up (default) - Start all services
- stop - Stop all services
- restart - Restart all services
- status - Show service status
- logs - Follow backend logs

After execution, show the output from the script which includes service status and endpoints.

## Work Summary
After running the script, provide:
- Which command was executed
- Service status (if applicable)
- Any errors or issues encountered
- If no issues: "No issues encountered"
