import { useDocsSidebar } from "@docusaurus/plugin-content-docs/client";
import { useHistory, useLocation } from "@docusaurus/router";
import styled from "@emotion/styled";

const TOC = styled.div`
`

export const TableOfContents = () => {
  const sidebar = useDocsSidebar();
  const location = useLocation();
  const history = useHistory();

  return (
    <TOC>
      <ul>
        {sidebar.items.map((item) => {
          if (item.type !== "category") {
            return;
          } else if (item.items.length !== 0) {
            return (
              <>
                {item.items.map((subItem) => {
                  if (subItem.type === "link" && /RFC-\d{4}: /.test(subItem.label)) {
                    return (
                      <li key={subItem.label}>
                        <a
                          href={subItem.href}
                          onClick={(e) => {
                            e.preventDefault();
                            history.push(subItem.href);
                          }}
                        >
                          {subItem.label}
                        </a>
                      </li>
                    );
                  }
                })}
              </>
            );
          }
        })}
      </ul>
    </TOC>
  );
};

export default TableOfContents;
