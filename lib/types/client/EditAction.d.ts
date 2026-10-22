/**
 * Per-message edit action: a toolbar button in the assistant-actions strip
 * that opens the single-message editor. It reuses the shipped toolbar Button
 * and is unavailable while the agent is running.
 * @module dsh-assistant-edit/client/EditAction
 */
import type { AssistantEditActionProps } from './slots.ts';
/**
 * One message's edit entry.
 * @param props - owner message identity, session kit, and injected face.
 */
export declare function EditAction({ messageId, useSession, rpc, sessionId, t, }: AssistantEditActionProps): import("react").JSX.Element;
