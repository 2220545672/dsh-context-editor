/**
 * `assistant-edit` namespace dictionaries.
 */
/** Simplified Chinese dictionary (the key-set source of truth). */
export const zh = {
    'action.edit': '编辑',
    'action.runningHint': '会话进行中，暂不可编辑',
    'action.editActive': '编辑中',
    'dialog.title': '编辑上下文',
    'dialog.close': '关闭',
    'dialog.empty': '当前会话还没有可编辑的助手消息',
    'dialog.loading': '加载中…',
    'dialog.restore': '恢复原文',
    'dialog.hint': '保存后立即生效',
    'dialog.replyLabel': '回复内容',
    'dialog.reasoningLabel': '思考链（可留空删除）',
    'dialog.save': '保存',
    'dialog.saving': '保存中…',
    'dialog.runningNotice': 'Agent 正在运行，暂时无法编辑',
    'row.saved': '已保存',
    'row.edited': '已编辑',
    'row.interrupted': '已停止',
    'row.count': '条消息',
    'error.generic': '保存失败，已保留原始内容',
    'error.sessionNotFound': '会话不在当前进程中，无法编辑',
    'error.messageNotFound': '找不到这条消息，可能已被移除',
    'error.messageEol': '这条消息已被更新的内容替换，无法再编辑',
    'edited.badge': '已编辑',
};
/** English dictionary. */
export const en = {
    'action.edit': 'Edit',
    'action.runningHint': 'Session is running; editing is temporarily unavailable',
    'action.editActive': 'Editing',
    'dialog.title': 'Edit context',
    'dialog.close': 'Close',
    'dialog.empty': 'No editable assistant messages in this session yet',
    'dialog.loading': 'Loading…',
    'dialog.restore': 'Restore original',
    'dialog.hint': 'Takes effect immediately after saving',
    'dialog.replyLabel': 'Reply',
    'dialog.reasoningLabel': 'Reasoning (empty to remove)',
    'dialog.save': 'Save',
    'dialog.saving': 'Saving…',
    'dialog.runningNotice': 'The agent is running; editing is disabled',
    'row.saved': 'Saved',
    'row.edited': 'Edited',
    'row.interrupted': 'Stopped',
    'row.count': 'messages',
    'error.generic': 'Save failed — the original content was kept',
    'error.sessionNotFound': 'Session is not live in this process',
    'error.messageNotFound': 'Message not found; it may have been removed',
    'error.messageEol': 'This message was already replaced and can no longer be edited',
    'edited.badge': 'Edited',
};
/** Dictionary namespace id. */
export const NS = 'assistant-edit';
