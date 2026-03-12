# Package Create Helper Slice Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Make `TPackageManager.CreatePackage` reuse the existing package metadata helper instead of hand-assembling `package.json`.

**Architecture:** Keep directory checks and file writes in `CreatePackage`, but route default metadata generation through `GeneratePackageMetadataJson` / `GeneratePackageMetadataJsonCore`. Preserve the existing default fields while avoiding duplicate JSON assembly logic.

**Tech Stack:** Object Pascal (FPC/Lazarus), JSON metadata helpers, focused Pascal regression tests.

---
