---
# ==============================================================================
# HOW TO EDIT THIS ENTITY:
# 1. Modify the FIELDS below (e.g., set parent, description, etc.).
# 2. To RENAME, update the 'key' field then run the build-index.ps1 script.
# 3. Always run scripts/build-index.ps1 to sync changes with the body and index.
# ==============================================================================

template_version: 37 # Still using v37 folder but updated naming convention.

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

# [ description ] ------------------------------------------------------------ #
# One sentence overview of what this project is.
description: ""
# ---------------------------------------------------------- #

# [ slogan ] ---------------------------------------------------------------- #
# Secondary catchy phrase or vision statement.
slogan: ""
# ---------------------------------------------------------- #

# [ category ] ----------------------------------------------------------------- #
# More granular classification.
category: ""
# ---------------------------------------------------------- #

# [ First Trend ] ------------------------------------------------------------ #
# Primary trend data.
first_trend_title: ""
first_trend_description: ""
first_trend_reference: ""
# ---------------------------------------------------------- #

# [ Second Trend ] ----------------------------------------------------------- #
# Secondary trend data.
second_trend_title: ""
second_trend_description: ""
second_trend_reference: ""
# ---------------------------------------------------------- #

# [ Third Trend ] ------------------------------------------------------------ #
# Tertiary trend data.
third_trend_title: ""
third_trend_description: ""
third_trend_reference: ""
# ---------------------------------------------------------- #

# [ Trend Notes ] ------------------------------------------------------------ #
# General notes for any other trends.
trend_notes: ""
# ---------------------------------------------------------- #

# [ First Benefit ] ----------------------------------------------------------- #
# Primary benefit data.
first_benefit_title: ""
first_benefit_description: ""
first_benefit_reference: ""
# ---------------------------------------------------------- #

# [ Second Benefit ] ---------------------------------------------------------- #
# Secondary benefit data.
second_benefit_title: ""
second_benefit_description: ""
second_benefit_reference: ""
# ---------------------------------------------------------- #

# [ Third Benefit ] ----------------------------------------------------------- #
# Tertiary benefit data.
third_benefit_title: ""
third_benefit_description: ""
third_benefit_reference: ""
# ---------------------------------------------------------- #

# [ Benefit Notes ] ----------------------------------------------------------- #
# General notes for any other benefits.
benefit_notes: ""
# ---------------------------------------------------------- #

# [ notes ] ------------------------------------------------------------------ #
# Freeform. Additional context, blockers, reminders.
notes: ""
# ---------------------------------------------------------- #

# ##############################################################################
# ##  AUTO-GENERATED FIELDS  (do not edit — overwritten by build-index.ps1)   ##
# ##############################################################################

# [ children ] --------------------------------------------------------------- #
# Titles of entities whose 'parent' field matches THIS entity's 'title'.
# Auto-populated by build-index.ps1 based on TITLE matching. 
# Do not edit manually.
children: ""
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

> **Children:** {{children}}

---

## Overview

{{description}}

## Trends

### First Trend: {{first_trend_title}}
> {{first_trend_description}}
> **Reference:** {{first_trend_reference}}

### Second Trend: {{second_trend_title}}
> {{second_trend_description}}
> **Reference:** {{second_trend_reference}}

### Third Trend: {{third_trend_title}}
> {{third_trend_description}}
> **Reference:** {{third_trend_reference}}

#### Other Trends & Notes
{{trend_notes}}

## Benefits

### First Benefit: {{first_benefit_title}}
> {{first_benefit_description}}
> **Reference:** {{first_benefit_reference}}

### Second Benefit: {{second_benefit_title}}
> {{second_benefit_description}}
> **Reference:** {{second_benefit_reference}}

### Third Benefit: {{third_benefit_title}}
> {{third_benefit_description}}
> **Reference:** {{third_benefit_reference}}

#### Other Benefits & Notes
{{benefit_notes}}

## Notes

{{notes}}
