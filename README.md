# Claude Code Skills by Blair

Production-ready skills for enhanced Claude Code development workflows.

## Installation

Add this marketplace to your Claude Code:

```shell
/plugin marketplace add blairanderson/skills
```

Then install individual skills:

```shell
/plugin install @blairanderson-skills
```

## Available Skills

| Skill | Description |
|-------|-------------|
| [code-spec](skills/code-spec) | Generate structured code specifications |
| [rails-authentication](skills/rails-authentication) | End-to-end Rails 8 authentication setup with session management, OAuth, 2FA, and more |
| [cleanup](cleanup) | Switch back to master, pull with rebase, and delete the current feature branch |

## Contributing

Want to add your own skills to this marketplace?

1. Fork this repository
2. Create a new skill directory under `skills/`
3. Write your `SKILL.md` following the [Agent Skills standard](https://agentskills.io)
4. Add an entry to `.claude-plugin/marketplace.json`
5. Submit a pull request

## License

MIT - See LICENSE file for details
