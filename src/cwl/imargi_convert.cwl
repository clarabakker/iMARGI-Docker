#!/usr/bin/env cwl-runner

class: CommandLineTool

cwlVersion: v1.0

requirements:
- class: DockerRequirement
  dockerPull: ""

- class: "InlineJavascriptRequirement"

inputs:
  out_format:
    type: string
    inputBinding:
      separate: true
      prefix: "-f"
      position: 1

  input_file:
    type: File
    inputBinding:
      separate: true
      prefix: "-i"
      position: 3

  out_file:
    type: string
    inputBinding:
      separate: true
      prefix: "-o"
      position: 4


  mcool_file:
    type: File
    outputBinding:
      glob:"$(inputs.outdir + '/' + '.mcool')"

baseCommand: ["imargi_convert.sh"]
