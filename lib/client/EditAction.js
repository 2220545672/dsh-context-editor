import { jsx as _jsx, Fragment as _Fragment, jsxs as _jsxs } from "react/jsx-runtime";
/**
 * Per-message edit action: a toolbar button in the assistant-actions strip
 * that opens the single-message editor. It reuses the shipped toolbar Button
 * and is unavailable while the agent is running.
 * @module dsh-assistant-edit/client/EditAction
 */
import { useCallback, useEffect, useRef, useState, useSyncExternalStore } from 'react';
import { Button, IconEditOutlineRegular, Tooltip, } from '@deepseek-ai/dsh-client-ui-primitives';
import { EditModal } from "./EditModal.js";
import { ensureMessageEdits, messageEditsOf, subscribeMessageEdits } from "./message-edits.js";
import css from './assistant-edit.module.css';
/** One-time attention color: shown until the user opens the editor once. */
const USED_KEY = 'dsh-assistant-edit:used:v1';
let usedInMemory = false;
const usedListeners = new Set();
/** Read the persisted "the user has clicked the pencil" flag. */
function readUsed() {
    if (usedInMemory)
        return true;
    try {
        return globalThis.localStorage?.getItem(USED_KEY) === '1';
    }
    catch {
        return false;
    }
}
/** Watch the shared first-click flag so every pencil switches together. */
function subscribeUsed(listener) {
    usedListeners.add(listener);
    return () => { usedListeners.delete(listener); };
}
/** Persist the click so the neutral toolbar color is used from now on. */
function rememberUsed() {
    if (readUsed())
        return;
    usedInMemory = true;
    try {
        globalThis.localStorage?.setItem(USED_KEY, '1');
    }
    catch {
        // Storage can be unavailable in private/embedded contexts; the in-memory
        // flag still changes the color for this page lifetime.
    }
    for (const listener of usedListeners)
        listener();
}
/**
 * One message's edit entry.
 * @param props - owner message identity, session kit, and injected face.
 */
export function EditAction({ messageId, useSession, rpc, sessionId, t, }) {
    // The addressed fragment is immutable and cache-stable; reuse it for the
    // closure below rather than a second read. `running` gates the pencil.
    const running = useSession(snapshot => snapshot.running);
    const subscribe = useCallback((listener) => subscribeMessageEdits(sessionId, listener), [sessionId]);
    const read = useCallback(() => messageEditsOf(sessionId), [sessionId]);
    const edits = useSyncExternalStore(subscribe, read, read);
    const edited = edits.has(messageId);
    useEffect(() => {
        if (rpc !== undefined)
            void ensureMessageEdits(sessionId, rpc);
    }, [sessionId, rpc]);
    const [open, setOpen] = useState(false);
    const used = useSyncExternalStore(subscribeUsed, readUsed, readUsed);
    const [justEdited, setJustEdited] = useState(false);
    const justEditedTimer = useRef(null);
    const openModal = useCallback(() => {
        rememberUsed();
        setJustEdited(false);
        setOpen(true);
    }, []);
    const closeModal = useCallback((didEdit) => {
        setOpen(false);
        if (!didEdit)
            return;
        setJustEdited(true);
        // Retire the transient "已编辑" state after a beat; the durable truth is
        // the host-side replacement event, not this badge.
        if (justEditedTimer.current !== null)
            clearTimeout(justEditedTimer.current);
        justEditedTimer.current = setTimeout(() => { setJustEdited(false); }, 2500);
    }, []);
    const label = running
        ? t('action.runningHint')
        : edited || justEdited ? t('edited.badge') : t('action.edit');
    const className = [used ? css.neutralAction : '', running ? css.disabledAction : '']
        .filter(Boolean).join(' ') || undefined;
    return (_jsxs(_Fragment, { children: [_jsx(Tooltip, { label: label, side: "bottom", children: _jsx(Button, { variant: used ? 'ghost' : 'toolbar', size: "sm", className: className, icon: _jsx(IconEditOutlineRegular, { size: 16 }), "aria-label": label, "aria-disabled": running || undefined, onClick: running ? undefined : openModal }) }), open && (_jsx(EditModal, { messageId: messageId, sessionId: sessionId, rpc: rpc, t: t, running: running, onClose: closeModal }))] }));
}
