"""Nutrient-wise comparison logic, independent of HTTP routing."""
from .schemas import NutrientToleranceOut, ToleranceIn, ToleranceOut


def compare_readings(request: ToleranceIn) -> ToleranceOut:
    nutrient_results: dict[str, NutrientToleranceOut] = {}
    for name in ("nitrogen", "phosphorus", "potassium"):
        measured = getattr(request.measured, name)
        reference = getattr(request.reference, name)
        tolerance = (
            getattr(request.tolerances_mg_kg, name)
            if request.tolerances_mg_kg is not None
            else request.tolerance_mg_kg
        )
        assert tolerance is not None
        nutrient_results[name] = NutrientToleranceOut(
            measured=measured,
            reference=reference,
            absolute_error=abs(measured - reference),
            tolerance_mg_kg=tolerance,
            within_tolerance=abs(measured - reference) <= tolerance,
        )
    return ToleranceOut(
        passed=all(result.within_tolerance for result in nutrient_results.values()),
        nutrients=nutrient_results,
    )
