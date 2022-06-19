package dev.ervinszilagyi.cwmetrics;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

@RestController
@RequestMapping("/people")
public record PeopleController(PeopleService peopleService) {
    @GetMapping
    public List<Person> getPeople() {
        return peopleService.getPeople();
    }

    @GetMapping("/{id}")
    public Person getPerson(@PathVariable Integer id) {
        return peopleService.getPerson(id);
    }
}
