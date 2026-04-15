虽然觉得TDD没什么卵用，但实际工作中还是必须要使用TDD，这不最近就做了一个使用TDD的方式开发SpringBoot的例子。


下面阐述一下如何开发一个RestFul的GET请求，从数据库中读取数据并返回。

# 创建Integration Test
第一步可以从IntegrationTest开始，即模拟真实发送一个HTTP请求，然后检验返回的Response。简单起见，第一步只校验状态值：

```java
@RunWith(SpringRunner.class)
@SpringBootTest(webEnvironment = WebEnvironment.RANDOM_PORT)
public class IntegrationTest {

  @Autowired
  private TestRestTemplate testClient;

  @Test
  public void should_get_computer_list_when_call_list_computer_api() {
    ResponseEntity<List<ComputerDto>> response = testClient.exchange(
        "/computers",
        HttpMethod.GET,
        null,
        new ParameterizedTypeReference<List<ComputerDto>>() {
        });
    assertEquals(HttpStatus.OK, response.getStatusCode());
  }
}
```
这里特意使用WebEnvironment.RANDOM_PORT以使得Spring启动一个接近真实的Server，来测试我们的请求。当然这个测试会挂了，因为Controller都还没写呢。所以下一个先来创建Controller，但是呢，TDD通常从测试开始写起，所以来测试Controller吧。

# Controller Test

测试Controller就是单元测试了，不需要测试其他的组件（比如service什么的)。
```java
@RunWith(SpringRunner.class)
@WebMvcTest(controllers = ComputerController.class)
public class ComputerControllerTest {

  @Autowired
  private MockMvc mockMvc;

  @Test
  public void should_get_a_list_when_get_computers() throws Exception {
    mockMvc.perform(MockMvcRequestBuilders.get("/computers"))
        .andExpect(status().isOk());
  }
}
```
然后就是需要创建一个Controller，让测试可以过：

```java
@RestController("/computers")
public class ComputerController {

  @GetMapping
  public List<ComputerDto> getComputers() {
    return null;
  }
}
```
到这里基本上集成测试也可以过了。所以你可以先commit一次了。然后，当然我们不能把逻辑放到Controller里面啊，我们需要一个Service来处理业务逻辑。这个Service又会从数据库中读取数据。在用到Repository之前，我们可能需要先改一下我们的controller测试，因为到目前为止并没有校验实际的字段，只是校验了返回状态码，现在可以开始校验了：

```java
  @MockBean
  private ComputerService computerService;

  @Test
  public void should_get_a_list_when_get_computers() throws Exception {
    given(computerService.getComputers())
        .willReturn(
            Collections.singletonList(
                new ComputerDto(1, "MacBook 2015", "Haifeng Li", "2019-09-10")
            ));
    mockMvc.perform(MockMvcRequestBuilders.get("/computers"))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$", hasSize(1)))
        .andExpect(jsonPath("$[0].id").value(1))
        .andExpect(jsonPath("$[0].type").value("MacBook 2015"))
        .andExpect(jsonPath("$[0].owner").value("Haifeng Li"))
        .andExpect(jsonPath("$[0].createTime").value("2019-09-10"))
        .andDo(print());
  }
```

这里我们把Service给Mock掉，因此可以控制它的行为，实际的Service就一个空函数就可以了。

# Service
这时候，可以考虑实现Service了，因为Service需要读取数据库，所以Service需要引入一个Repository来查询数据库，我们可以Mock掉Repository，来测service的逻辑：

```java
@RunWith(MockitoJUnitRunner.class)
public class ComputerServiceTest {

  @Mock
  private ComputerRepository computerRepository;

  @InjectMocks
  private ComputerService computerService;

  @Test
  public void should_return_computer_list_when_get_all_computers() throws ParseException {
    ComputerEntity stored = new ComputerEntity(1,
        "MacBook 2015",
        "Haifeng Li",
        new SimpleDateFormat("dd/MM/yyyy").parse("01/09/2019"));
    given(computerRepository.findAll()).willReturn(Collections.singletonList(stored));

    List<ComputerDto> computers = computerService.getComputers();

    assertEquals(1, computers.size());
    assertEquals(1, computers.get(0).getId());
    assertEquals("MacBook 2015", computers.get(0).getType());
    assertEquals("Haifeng Li", computers.get(0).getOwner());
    assertEquals("2019-09-01", computers.get(0).getCreateTime());
  }
}
```
同样Repository里面也就一个空函数就行了，但是这时候得把Service 的逻辑写完，让测试可以通过，这样Service的任务就完成了，其他测试也全部都可以通过。

# Repository

最后一步就是来实现Repository了，这里需要使用DataJpaTest，用内存数据库进行测试：

```java
@RunWith(SpringRunner.class)
@DataJpaTest
public class ComputerRepositoryTest {

  @Autowired
  private TestEntityManager entityManager;

  @Autowired
  private ComputerRepository computerRepository;

  @Before
  public void prepareData() throws ParseException {
    entityManager.persistAndFlush(new ComputerEntity(1,
        "MacBook 2015",
        "Haifeng Li",
        new SimpleDateFormat("dd/MM/yyyy").parse("01/09/2019"))
    );
    entityManager.persistAndFlush(new ComputerEntity(2,
        "Desktop",
        null,
        new SimpleDateFormat("dd/MM/yyyy").parse("02/09/2019"))
    );
  }

  @Test
  public void should_return_all_records_in_db_when_find_all() {
    List<ComputerEntity> entities = computerRepository.findAll();
    assertEquals(2, entities.size());
  }
}
```
因为Spring JPA你只需要写一堆interface，测试这里的逻辑还是十分有必要的。所以到这一步为止，基本上程序的功能就已经实现了，唯一需要做的就是改一下配置来连接到真是的数据库。整个代码可以在我的[Github](https://github.com/soleverlee/computer-inventory.git)上面找到。