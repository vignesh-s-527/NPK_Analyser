"""Small, source-attributed RAG index. Extend only with reviewed publications."""
from dataclasses import dataclass


@dataclass(frozen=True)
class KnowledgePassage:
    topic_terms: frozenset[str]
    text: str
    title: str
    url: str


KNOWLEDGE_BASE = (
    KnowledgePassage(
        topic_terms=frozenset("soil test fertilizer rate crop calibration method extraction local".split()),
        text=("Fertilizer rates should be based on standard soil tests and fertilizer guidelines "
              "correlated and calibrated for the local region and crop. Soil type, pH, precipitation, "
              "temperature, organic matter, rotation and parent material can affect nutrient availability."),
        title="University of Minnesota Extension - Can soil health tests determine fertilizer needs",
        url="https://extension.umn.edu/natural-resources/conservation/agricultural-soil-and-water/can-soil-health-tests-determine-fertilizer-needs",
    ),
    KnowledgePassage(
        topic_terms=frozenset("fertilizer label nutrient concentration N P K phosphorus oxide potassium oxide rate".split()),
        text=("Fertilizer labels list nutrient percentages. A valid soil-test and crop guideline must "
              "first establish nutrient need; divide that nutrient amount by the nutrient fraction in "
              "the product. N-P-K labels may express phosphorus as P2O5 and potassium as K2O."),
        title="University of Minnesota Extension - Interpreting soil tests for fruit and vegetable crops",
        url="https://extension.umn.edu/agriculture/specialty-crops/interpreting-soil-tests-for-fruit-and-vegetable-crops",
    ),
    KnowledgePassage(
        topic_terms=frozenset("soil sample laboratory pH organic matter test report".split()),
        text=("A laboratory soil test helps determine soil nutrient levels, pH and organic matter and "
              "supports decisions about whether to apply nutrients or amendments. Follow the laboratory's "
              "sampling instructions and local recommendations."),
        title="University of Minnesota Extension - Soil testing for lawns and gardens",
        url="https://extension.umn.edu/garden-and-home/yard-and-garden/gardening-in-minnesota/soil-testing-for-lawns-and-gardens",
    ),
)


def retrieve(question: str, *, limit: int = 2) -> list[KnowledgePassage]:
    terms = {term.strip(".,?!:;").casefold() for term in question.split() if len(term) > 2}
    ranked = sorted(
        ((len(terms & passage.topic_terms), passage) for passage in KNOWLEDGE_BASE),
        key=lambda item: (item[0], item[1].title), reverse=True,
    )
    return [passage for score, passage in ranked[:limit] if score >= 2]
