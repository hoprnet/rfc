
import { useDocsSidebar } from '@docusaurus/plugin-content-docs/client';
import { useHistory, useLocation } from '@docusaurus/router';


export const TableOfContents = () => {
  const sidebar = useDocsSidebar();
  const location = useLocation();
  const history = useHistory();

  return (
    <div>
      <ul>
        {
          sidebar.items.map((item) => {
            if (item.type !== 'category') {
              return;
            }
            else if (item.items.length !== 0) {
              return (
                <>
                  {
                    item.items.map((subItem) => {
                      if (subItem.type === 'link' && subItem.label.includes('RFC-000')) {
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
                    })
                  }
                </>
              );
            }
          })
        }
      </ul>
    </div>
  );
};

export default TableOfContents;