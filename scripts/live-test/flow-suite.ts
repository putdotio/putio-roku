export type FlowId =
  | "auth"
  | "get-new-code"
  | "files"
  | "dialogs"
  | "settings"
  | "logout"
  | "playback"
  | "tracks";

export type FlowStepResult = {
  readonly id: FlowId;
  readonly status: "passed";
  readonly durationMs: number;
};

export type FlowRunContext = {
  readonly target: string;
  readonly artifactDir: string;
};

export type FlowRunner = (flowId: FlowId, context: FlowRunContext) => Promise<void>;

export const appFlowSmokeSuite: readonly FlowId[] = [
  "auth",
  "files",
  "dialogs",
  "settings",
  "get-new-code",
  "auth",
];

export const fullAppFlowSuite: readonly FlowId[] = [
  ...appFlowSmokeSuite,
  "playback",
  "tracks",
  "logout",
  "auth",
];

const flowIdSet = new Set<FlowId>([
  "auth",
  "get-new-code",
  "files",
  "dialogs",
  "settings",
  "logout",
  "playback",
  "tracks",
]);

export function parseFlowList(rawFlowList: string): FlowId[] {
  const flows = rawFlowList
    .split(",")
    .map((flow) => flow.trim())
    .filter((flow) => flow.length > 0);

  if (flows.length === 0) {
    throw new Error("expected at least one flow id");
  }

  return flows.map(parseFlowId);
}

export function parseFlowId(rawFlowId: string): FlowId {
  if (flowIdSet.has(rawFlowId as FlowId)) {
    return rawFlowId as FlowId;
  }

  throw new Error(
    `unknown flow "${rawFlowId}". Expected one of: ${Array.from(flowIdSet).join(", ")}`,
  );
}

export async function runFlowSuite(
  flows: readonly FlowId[],
  context: FlowRunContext,
  runFlow: FlowRunner,
): Promise<FlowStepResult[]> {
  const results: FlowStepResult[] = [];

  console.log(`flow suite: ${flows.join(", ")}`);
  console.log(`flow artifacts: ${context.artifactDir}`);

  for (const flowId of flows) {
    const startedAt = Date.now();
    console.log(`flow start: ${flowId}`);
    await runFlow(flowId, context);
    const durationMs = Date.now() - startedAt;
    results.push({ id: flowId, status: "passed", durationMs });
    console.log(`flow pass: ${flowId} (${durationMs}ms)`);
  }

  console.log(
    `flow suite passed: ${results.map((result) => `${result.id}:${result.durationMs}ms`).join(" ")}`,
  );

  return results;
}
