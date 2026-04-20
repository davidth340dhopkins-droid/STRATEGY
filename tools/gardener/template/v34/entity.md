---
# ==============================================================================
# HOW TO EDIT THIS ENTITY:
# 1. Modify the FIELDS below (e.g., set parent, description, etc.).
# 2. To RENAME, update the 'key' field then run the build-index.ps1 script.
# 3. Always run scripts/build-index.ps1 to sync changes with the body and index.
# ==============================================================================

template_version: 34 # Managed by build-index.ps1. Do not edit.

# ##############################################################################
# ##  SCHEMA FIELDS                                                           ##
# ##############################################################################

# [ key ] -------------------------------------------------------------------- #
# Unique identifier. Update this then run the build-index.ps1 script to
# automatically rename the underlying .md file. (Example: "arthurian")
key: ""
# ---------------------------------------------------------- #

# [ title ] ------------------------------------------------------------------ #
# Human-readable name of the project.
title: ""

# [ type ] ------------------------------------------------------------------- #
# Category of project. e.g. Business, Personal, Creative, Infrastructure.
type: ""
# ---------------------------------------------------------- #

# [ parent ] ----------------------------------------------------------------- #
# Key of the parent project. (e.g. "life-plan")
parent: ""
# ---------------------------------------------------------- #

# [ tagline ] ---------------------------------------------------------------- #
# A brief, catchy slogan or one-sentence value proposition.
tagline: ""

# [ slogan ] ---------------------------------------------------------------- #
# Secondary catchy phrase or vision statement.
slogan: ""
# ---------------------------------------------------------- #

# [ category ] ----------------------------------------------------------------- #
# More granular classification.
category: ""
# ---------------------------------------------------------- #

# [ trends ] ----------------------------------------------------------------- #
# Emerging opportunities, cultural shifts, or market trends this aligns with.
trends: ""
# ---------------------------------------------------------- #

# [ benefits ] --------------------------------------------------------------- #
# Primary personal or financial returns expected from this entity.
benefits: ""
# ---------------------------------------------------------- #

# [ description ] ------------------------------------------------------------ #
# One sentence overview of what this project is.
description: ""
# ---------------------------------------------------------- #

# [ notes ] ------------------------------------------------------------------ #
# Freeform. Additional context, blockers, reminders.
notes: ""
# ---------------------------------------------------------- #

# ##############################################################################
#
# 🛑 DO NOT EDIT THE MARKDOWN BODY OF THIS FILE! 🛑
# All changes made BELOW THE NEXT '---' LINE will be OVERWRITTEN.
#
---

# {{title}}

> _{{tagline}}_ _{{slogan}}_

> **Parent:** {{parent}} · {{type}} · {{category}} · {{key}}

---

## Overview

{{description}}

## Trends

{{trends}}

## Benefits

{{benefits}}

## Notes

{{notes}}
