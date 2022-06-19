package dev.ervinszilagyi.cwmetrics;

import org.springframework.stereotype.Service;

import java.util.List;
import java.util.concurrent.CopyOnWriteArrayList;

@Service
public class PeopleService {
    private final List<Person> people = new CopyOnWriteArrayList<>(List.of(
            new Person(1, "person1"), new Person(2, "person2")
    ));

    public List<Person> getPeople() {
        return people;
    }

    public Person getPerson(int id) {
        return people.stream().filter(person -> person.id() == id).findAny().orElseThrow();
    }
}
