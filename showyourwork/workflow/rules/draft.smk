"""
Defines the rule ``syw__preprocess`` to parse the config and build the
workflow graph.

Runs the script :doc:`preprocess` to generate the ``.showyourwork/config.json``
file containing metadata about the build and the workflow graph.

"""
from showyourwork import paths


rule:
    """
    Setup the temporary files for compilation.

    """
    name:
        "syw__preprocess_setup"
    message:
        "Preprocess: Setting up..."
    input:
        config["ms_tex"],
        config["tex_files_in"],
        "showyourwork.yml",
        "zenodo.yml" if (paths.user().repo / "zenodo.yml").exists() else [],
        stylesheet=(paths.showyourwork().resources / "styles" / "draft.tex").as_posix()
    output:
        temporary_tex_files(root=paths.user().preprocess),
        compile_dir=directory(paths.user().preprocess.as_posix()),
    params:
        metadata=False
    script:
        "../scripts/compile_setup.py"

rule:
    """
    Compile the manuscript into the article PDF.

    """
    name:
        "syw__preprocess_xml"
    message:
        "Preprocess: Generating XML tree..."
    input:
        temporary_tex_files(root=paths.user().preprocess),
        compile_dir=paths.user().preprocess.as_posix()
    output:
        (paths.user().preprocess / "showyourwork.xml").as_posix()
    conda:
        (paths.showyourwork().envs / "tectonic.yml").as_posix()
    shell:
        """
        cd "{input.compile_dir}"
        tectonic                  \\
            --chatter minimal     \\
            --keep-logs           \\
            --keep-intermediates  \\
            "{input[0]}"
        """

rule:
    """
    Generate a `config.json` file for the main build.

    This rule builds the article using ``tectonic``, but re-defines ``figure``,
    ``caption``, and ``label`` commands to print XML tags to a special log file.
    This way, we can use TeX to construct a full XML tree of the document for us,
    without any need for parsing the TeX file ourselves. This XML tree is then
    used to determine relationships between the figure scripts and the figure
    files.

    This rule also assembles information about the datasets and other script
    dependencies, as well as metadata about the git repo. It then packages
    all this up alongside the user's config settings into the file
    `config.json`, which is used as input to the main `showyourwork`
    workflow.

    """
    name:
        "syw__preprocess"
    message:
        "Preprocess: Setting up the workflow..."
    input:
        (paths.user().preprocess / "showyourwork.xml").as_posix()
    output:
        config["config_json"],
    script:
        "../scripts/preprocess_draft.py"

rule:
    name:
        "syw__compile_copy_pdf"
    message:
        "Copying the article PDF..."
    input:
        (paths.user().preprocess / "showyourwork.xml").as_posix()
    output:
        config["ms_pdf"]
    shell:
        """
        cp "{input}" "{output}"
        """
