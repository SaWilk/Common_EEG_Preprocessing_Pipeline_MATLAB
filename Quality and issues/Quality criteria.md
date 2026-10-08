**Quality criteria** 

derived from the JOSSS Website (especially from sections Author guides and Review guides: https://joss.readthedocs.io/en/latest)



* *Software License* 

There should be an OSI approved license included in the repository. Common licenses such as those listed on choosealicense.com are preferred. Note there should be an actual license file present in the repository not just a reference to the license.



* *Scope/Significance*

Review/Feedback/Adoption of the Software from other Research groups

Comparison to other available Tools

Citations might not be possible in time but maybe in preregistrations? 



* *Development*

Evidence of sustained development over time: commit history over an extended period (\~ 6 months), iterative improvements, Evolution of features, at least six months of public development history (Version tags/Releases, issues/pull requests), ideally with external engagement 



&#x09;- *Time span*

&#x09;Good: Commits distributed over 6+ months showing gradual feature development

&#x09;**OK: Development spanning 6+ months but with sporadic or bursty activity patterns (e.g., concentrated bursts, rather 	than steady continuous development)**

&#x09;Not acceptable: All or most commits concentrated in the last few weeks before submission



&#x09;- *Open development*

&#x09;Good: Repository public from inception with documented releases and community interaction

&#x09;**OK: Repository made public 6+ months ago with clear evidence of ongoing development**

&#x09;Not acceptable: Repository made public immediately before submission with limited public development history



&#x09;- *Collaborative effort*

&#x09;**Good: Multiple developers contributing to the codebase with evidence of iterative refinement through community 	feedback (issues, pull requests, code review)**

&#x09;OK: Single author but shows other evidence of community engagement, either in the repository or evidenced in the paper

&#x09;Not acceptable: Single author with no evidence of community engagement, external use, or collaborative input



* *Good practice*

Reusable and open-source project

License: OSI-approved license (required)

Documentation: README, installation instructions, usage examples, API documentation

Quality assurance: Automated tests, continuous integration, and/or documented verification processes

Releases: Tagged versions or formal release process

Community pathways: Clear contribution guidelines and support channels



Good: All elements present and well-maintained

**OK: Core elements present (license, docs, tests, contribution guidelines)**

Bad (not acceptable): Missing critical elements or appears to be a one-time code dump



* *README*

Present the core functionality for reviewers



&#x09;- *Statement of need* 

&#x09;Define problem solution, target audience and relation to other work



&#x09;- *Installation instructions* Documentation of software dependencies and automated procedure (ideally package manager)

&#x09;Good: The software is simple to install, and follows established distribution and dependency management approaches for the language being used

&#x09;OK: A list of dependencies to install, together with some kind of script to handle their installation (e.g., a Makefile)

&#x09;Bad (not acceptable): Dependencies are unclear, and/or installation process lacks automation



&#x09;- *Example usage*

&#x09;Include examples to solve real problems.



&#x09;- *API documentation*

&#x09;Good: All functions/methods are documented including example inputs and outputs

&#x09;OK: Core API functionality is documented

&#x09;Bad (not acceptable): API is undocumented

&#x09;

&#x09;- Community guidelines

&#x09;Guidelines for others for contribution, report of issues/problems, support



* *Functionality* and Tests

Reviewers will install software and verify functionality. Authors should include an automated test suite for core functionality



**Good: An automated test suite hooked up to continuous integration (GitHub Actions, Circle CI, or similar)**

OK: Documented manual steps that can be followed to objectively check the expected functionality of the software (e.g., a sample input file to assert behavior)

Bad (not acceptable): No way for you, the reviewer, to objectively assess whether the software works



* *Paper Content* (see Paper document for detailed description): Statement of need, State of the field, Software design, Research impact statement, AI usage disclosure
* Mark-Down and figure/image guidelines on the website (https://joss.readthedocs.io/en/latest/paper.html)



* *Other Considerations*

&#x09;- *Authorship* with substantial contributions to the software, but up to research groups

&#x09;- *Novelty* is not required, similar work should be cited

&#x09;- *Review categories*: Acceptance, Minor Revisions, Major Revisions (no rejections under review)

&#x09;- *Proprietary language*: Reviewers should be able to install it and might encourage compatibility with open source variants

&#x09;- *Paper branch* with paper.md, BibTeX plus figures, does not need to merged (if so, created from the default)

&#x09;- *Submission*: stored in clonable repository with software files online, issue tracker, permission of creating issues against repository



* *AI use*:

Author use: The use of generative AI is permitted for most aspects of a JOSS submission (e.g., software creation and review, generating documentation, assisting with paper authoring), however all such use must be disclosed in an “AI usage disclosure” statement which includes:

Tool use: The tools/models used (and versions) and where they were used (code, paper text, docs).

The nature and scope of assistance: e.g., code generation, refactoring, test scaffolding, copy-editing, drafting.

Confirmation of review: Authors must assert that human authors reviewed, edited, validated all AI-assisted outputs and made the core design decisions.



AI is not allowed for conversational interactions between authors and editors or reviewers unless it is being used for translation purposes.



Authors remain fully responsible for the accuracy, originality, licensing, and ethical/legal compliance of all submitted materials. Failure to provide a complete and accurate disclosure of AI usage may be considered an ethical breach. Consequences can include desk rejection, mandatory revisions, and post-publication correction or withdrawal. In cases of intentional misrepresentation or non-disclosure, JOSS reserves the right to notify the authors’ institutions, funders, and/or relevant professional or scholarly societies in accordance with standard research-integrity practices.



* Policies

&#x09;- *Disclosure* 

&#x09;All authors must disclose any potential conflicts of interest related to the research in their manuscript, including financial, personal, or professional relationships that may affect their objectivity. This includes any 	financial relationships, such as employment, consultancies, honoraria, stock ownership, or other financial interests that may be relevant to the research.



&#x09;- *Acknowledgement* 

&#x09;Authors should acknowledge all sources of financial support for the work and include a statement indicating whether or not the sponsor had any involvement in it.



* *Preprints* are welcome
* *Metadata*: generate metadata with automated script from JOSSS (optional)
* *Review process* requires timely responses to reviewer issues!

&#x09;







