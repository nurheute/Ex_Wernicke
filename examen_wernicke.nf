nextflow.enable.dsl=2

params.accession = 'M21012'
params.genome_dir = './genomes'
params.output_dir = './results'


process download_genbank {

    tag "$accession"
    publishDir "${params.output_dir}", mode: 'copy'

    input:
    val accession from params.accession

    output:
    path "${accession}.fasta" into genbank_fasta

    script:
    """
    wget "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?db=nuccore&id=${accession}&rettype=fasta&retmode=text" -O ${accession}.fasta
    """
}

process collect_genomes {

    tag "collect_genomes"

    input:
    path genome_dir from file(params.genome_dir)

    output:
    path genome_dir.collect { it.name.endsWith('.fasta') || it.name.endsWith('.fa') } into genome_fastas

    script:
    """
    # No transformation needed, just pass the files through
    """
}

process combine_fasta {

    tag "combine_fastas"
    publishDir "${params.output_dir}", mode: 'copy'

    input:
    path genbank from genbank_fasta
    path genomes from genome_fastas.collect()

    output:
    path "combined_genomes.fasta" into combined_fasta

    script:
    """
    cat ${genbank} ${genomes.join(' ')} > combined_genomes.fasta
    """
}

process run_mafft {

    tag "mafft"
    publishDir "${params.output_dir}", mode: 'copy'
    container "quay.io/biocontainers/mafft:7.505--h031d066_1"

    input:
    path fasta from combined_fasta

    output:
    path "aligned_genomes.fasta" into aligned_fasta
    

    script:
    """
    mafft --auto ${fasta} > aligned_genomes.fasta
    """
}

process run_trimal {

    tag "trimal"
    publishDir "${params.output_dir}", mode: 'copy'
    container "quai.io/biocontainers/trimal:1.4.1--h9ee0642_4"

    input:
    path aligned from aligned_fasta

    output:
    path "cleaned_alignment.fasta"
    path "trimal_report.html"

    script:
    """
    trimal -in ${aligned} -out cleaned_alignment.fasta -automated1 -htmlout trimal_report.html
    """
}


workflow {
    download_genbank(params.accession)
    collect_genomes(params.genome_dir)
    combine_fastas(downnload_genbank.out, collect_genomes.out)
    run_mafft(combine_fastas.out)
    run_trimal(run_mafft.out)
}


