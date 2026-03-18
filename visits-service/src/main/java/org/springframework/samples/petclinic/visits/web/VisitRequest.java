package org.springframework.samples.petclinic.visits.web;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import java.util.Date;

public record VisitRequest(
    @NotBlank String description,
    @NotNull Date date
) {}