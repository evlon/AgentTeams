import { randomUUID } from 'node:crypto'
import z from '@deepseek-ai/schemastery'
import { installModelSelection } from '@deepseek-ai/dsh-agent'
import { freezeMessage, MessageId } from '@deepseek-ai/dsh-llm'
import { SessionId } from '@deepseek-ai/dsh-session'
import { matrixEventMessageId } from './message-id.js'
import { executeAttempt } from './turn.js'


export const name = 'agentteams-headless-runner'
export const inject = ['agentDefaultModel', 'agents', 'sessions', 'sessionPersistence']

export const Config = z.object({
  task: z.string().required(),
  sessionId: z.string().default(''),
  resume: z.boolean().default(false),
  eventId: z.string().default(''),
  attempt: z.number().step(1).min(1).default(1),
})

function messageId(eventId, attempt) {
  if (!eventId) return MessageId(randomUUID())
  return MessageId(matrixEventMessageId(eventId, attempt))
}

function userMessage(task, id) {
  return freezeMessage({
    id,
    role: 'user',
    content: [{ type: 'text', text: task }],
    source: { kind: 'user' },
  })
}

async function openAgent(ctx, sessionId, resume, selection) {
  const options = {
    agentOptions: { provider: selection.provider, model: selection.model },
    setup: (agentCtx) => {
      installModelSelection(agentCtx, { current: selection, assembled: undefined })
    },
  }
  const agents = ctx.get('agents')
  const persistence = ctx.get('sessionPersistence')
  if (persistence === undefined) {
    throw new Error('agentteams-headless-runner: sessionPersistence is required')
  }
  // DSH's sessionPersistence.list() yields snapshots shaped
  // { header, revision, sizeBytes } — the session identity lives on
  // snapshot.header.id, NOT on the snapshot itself. Reading `header.id` off the
  // snapshot silently yields undefined for every entry, so a persisted session
  // was never recognised, every continuation turn took the "missing session"
  // branch, and resume always failed with:
  //   requested resume for missing DSH session <id>
  // Accept both shapes so the adapter keeps working if a future DSH returns
  // bare headers again.
  const persisted = (await persistence.list()).some(
    entry => (entry?.header?.id ?? entry?.id) === sessionId,
  )
  if (persisted) {
    return agents.resume({ ...options, resumeSessionId: sessionId })
  }
  if (resume) {
    throw new Error(`requested resume for missing DSH session ${sessionId}`)
  }
  return agents.create({ ...options, sessionId, meta: { cwd: process.cwd() } })
}

async function run(ctx, config, io) {
  await ctx.get('loader')?.await()
  const defaultModel = ctx.get('agentDefaultModel')
  const sessions = ctx.get('sessions')
  const agents = ctx.get('agents')
  if (defaultModel === undefined || sessions === undefined || agents === undefined) return

  const selection = defaultModel.currentSelection()
  const sessionId = SessionId(config.sessionId || `session-${randomUUID()}`)
  const handle = await openAgent(ctx, sessionId, config.resume, selection)
  // DeepSeek Harness agents.create/resume return an AgentHandle { agent, dispose }.
  const agent = handle.agent
  await agent.whenIdle()

  const id = messageId(config.eventId, config.attempt)
  const outcome = await executeAttempt({
    // DSH 0.1.5 removed the `agent.session.events` getter; use snapshotEvents() instead.
    getEvents: () => agent.session.snapshotEvents(0, agent.session.seq),
    id,
    firstSeq: agent.session.seq,
    eventId: config.eventId,
    followup: () => agent.followup(userMessage(config.task, id)),
    whenIdle: () => agent.whenIdle(),
    flush: () => sessions.flush(agent.session),
  })
  await handle.dispose()

  io.stdout.write((outcome?.text ?? '') + '\n')
  if (outcome?.reason?.kind === 'error') {
    io.stderr.write(`dsh: ${outcome.reason.error.code}: ${outcome.reason.error.message}\n`)
  }
  io.exit(outcome?.reason?.kind === 'completed' ? 0 : 1)
}

export function apply(ctx, config) {
  const exit = ctx.get('appExit')
  if (exit === undefined) {
    throw new Error('agentteams-headless-runner: ctx.appExit is required')
  }
  const io = { stdout: process.stdout, stderr: process.stderr, exit }
  void run(ctx, config, io).catch((error) => {
    io.stderr.write(`dsh: ${error instanceof Error ? error.message : String(error)}\n`)
    io.exit(1)
  })
}
