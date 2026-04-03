# Strategy Garden Guide

This **Strategy Garden** is a system for managing and scaling
projects with the assistance of AI. It contains a structured
lifecycle for transforming raw data and ideas into valuable
products, and projects are gathered together into a single
repository accessible by AI.

**Caution:** This repository is a work-in-progress and any
included documentation may not accurately reflect its current
state.

## **Rationale**

Artificial intelligence is a powerful technology for achieving
one's goals. It has strengths and weaknesses — which are
complemented by human intelligence — and the best results may
always be achieved by applying both forms of intelligence
together.

Artificial intelligence:

- is a specialist and not a generalist,

- learns slowly and periodically (rather than continuously),
  and

- produces work that is "high-volume" (but "low-signal").

Because of these characteristics, optimal AI-assisted work
tends to:

- progress "radially" rather than "linearly",

- progress allometrically rather than isometrically, and

- be "process-oriented" rather than "outcome-oriented."

Human work tends to involve focusing on a single objective and
using experimentation and iteration to incrementally build
towards it until it is achieved. Humans learn continuously and
are generalists, so the results from any failed attempt will be
rapidly synthesized. As humans operate in the real world (which
is slow and expensive), there tends to be more value in gaining
the desired result quickly than in understanding why it was
achieved.

Conversely, AI-assisted work relies on abstraction rather than
experimentation.

AI agents have a U-shaped efficiency curve: they are most
effective working on outcomes that are very general or very
specific and struggle at those in between. As complex tasks
involve starting with a broad problem space and making it
progressively narrower, the way that we deal with the
inevitable problem of the "messy middle" is to pre-empt it. We
begin by abstracting the task into a series of precise steps
for the AI to follow. We can use the AI itself to help us with
the abstraction process and, if necessary, continue adding
layers of abstraction until executing the task successfully is
sufficiently deterministic.

A productive AI-assisted workflow involves multiple parallel
attempts and frequent testing gates.

Once an objective is abstracted into a series of steps, it is
useful for the AI to make many parallel attempts at executing
each step for human review. The human then selects the best
attempt with which to proceed, or elects to modify the process
(which can be done with the help of the AI), or both.

Because AI operates in the digital realm, process design is
more valuable as any result of a process can be multiplied and
scaled rapidly. Just as multiple parallel attempts may be made
at the micro level to execute a step correctly, multiple 
attempts may be made at the macro level to design the correct
process.

This 'Strategy Garden' is fashioned to build and discover the
optimal project development process to incorporate the latest
agentic tools whilst advancing the projects themselves. It
permits quickly switching between projects and developing
projects at different rates in parallel ("radial, allometric"
development), rapidly copying process-related learnings across
projects, and compiling all project-related activity into a
single location to facilitate cross-project pollination, the
construction of a knowledge repository and the aforementioned
process/es.

## **How It Works (Overview)**

**Gather & Sort**:

Firstly, ideas are gathered in the "glossary"
([`glossary.md`](./glossary.md)). These ideas may optionally be
sourced from raw data that is dumped in the `compost/` folder,
which is distilled into key terms, concepts, or potential brand
identities.

**Plant**:

Secondly, select glossary entries are converted into "seed"
entities. To do so, each idea is assigned a key and a document
is composed for it in the
[`entities/seeds/`](./entities/seeds/) subdirectory. These may
be freeform documents or they may be created (and/or processed)
using the "gardener" tool. Processed seed documents are added
to the gardener's "index"
([`gardener/entities/_index.md`](./gardener/entities/_index.md))
which makes it easier to edit multiple seed documents at once.
(The gardener processes seed documents with the use of a common
template and the index is to be rebuilt whenever a managed seed
document is edited or the template is updated.)

**Cultivate**:

Thirdly, select seed entities are converted into "sprout
projects" using the "nursery" tool. Sprouts are assigned their
own folder (in [`entities/sprouts/`](./entities/sprouts/)) and
their seed document is moved to this location. The nursery tool
sets up a standardized DevOps pipeline for the project with
feature worktrees and version control.* It does this by copying
a package into the target sprout directory on initialization
and triggering its setup script.* If a change is made to the
base nursery package, the update may be pulled into the sprout
directories on a case-by-case basis.* The nursery package is
designed to be configurable to work with whichever stack an
individual project is using and git.*

*(IMPORTANT NOTE: The described features of the nursery tool
are currently under development.)

## **Learn More**

For more information as to how the system works and how to use
it, see [`README.md`](./README.md). For how the system is
organized, see [`index.md`](./index.md).
