/**
 * Serialize config to YAML string with helpful comments.
 *
 * @param config - Partial config object (schema required, context/rules optional)
 * @returns YAML string ready to write to file
 */
export function serializeConfig(config) {
    const defaultContext = '语言：中文（简体）\n所有产出物必须用简体中文撰写。';
    const lines = [];
    // Schema (required)
    lines.push(`schema: ${config.schema}`);
    lines.push('');
    // Context section with comments
    lines.push('# Project context (optional)');
    lines.push('# This is shown to AI when creating artifacts.');
    lines.push('# Add your tech stack, conventions, style guides, domain knowledge, etc.');
    lines.push('# Example:');
    lines.push('#   context: |');
    lines.push('#     Tech stack: TypeScript, React, Node.js');
    lines.push('#     We use conventional commits');
    lines.push('#     Domain: e-commerce platform');
    const context = config.context ?? defaultContext;
    if (context.length > 0) {
        lines.push('context: |');
        for (const line of context.split('\n')) {
            lines.push(`  ${line}`);
        }
    }
    lines.push('');
    // Rules section with comments
    lines.push('# Per-artifact rules (optional)');
    lines.push('# Add custom rules for specific artifacts.');
    lines.push('# Example:');
    lines.push('#   rules:');
    lines.push('#     proposal:');
    lines.push('#       - Keep proposals under 500 words');
    lines.push('#       - Always include a "Non-goals" section');
    lines.push('#     tasks:');
    lines.push('#       - Break tasks into chunks of max 2 hours');
    return lines.join('\n') + '\n';
}
//# sourceMappingURL=config-prompts.js.map
